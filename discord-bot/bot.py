"""
Talaxie Discord Bot
===================
Bot communautaire pour le serveur Discord Talaxie.
Fonctionnalités : onboarding, modération, filtre anti-credential,
commandes utilitaires (/doc, /issue), rôles par réaction.

Usage :
    pip install -r requirements.txt
    cp .env.example .env
    # Éditer .env avec tes valeurs
    python bot.py
"""
import asyncio
import re
from datetime import datetime, timedelta
from typing import Optional

import aiohttp
import discord
from discord import app_commands
from discord.ext import commands

import config

# ---------------------------------------------------------------------------
# Initialisation
# ---------------------------------------------------------------------------

intents = discord.Intents.default()
intents.members = True
intents.message_content = True
intents.reactions = True

bot = commands.Bot(command_prefix="!", intents=intents)

# Dictionnaire en mémoire pour les warnings (restart = reset)
# En production, utiliser une base SQLite ou Redis
warnings_db: dict[int, int] = {}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def contains_credentials(content: str) -> list[str]:
    """Scanne un message à la recherche de fuites de credentials."""
    matches = []
    for pattern in config.CREDENTIAL_PATTERNS:
        if re.search(pattern, content):
            matches.append(pattern)
    return matches


def create_mod_embed(
    action: str,
    moderator: discord.Member,
    target: discord.Member,
    reason: str,
    color: discord.Color = discord.Color.orange(),
) -> discord.Embed:
    """Crée un embed standardisé pour les actions de modération."""
    embed = discord.Embed(
        title=f"🔨 {action}",
        color=color,
        timestamp=datetime.utcnow(),
    )
    embed.add_field(name="Modérateur", value=moderator.mention, inline=True)
    embed.add_field(name="Cible", value=target.mention, inline=True)
    embed.add_field(name="Raison", value=reason, inline=False)
    embed.set_footer(text=f"ID cible : {target.id}")
    return embed


# ---------------------------------------------------------------------------
# Cog : Onboarding
# ---------------------------------------------------------------------------

class OnboardingCog(commands.Cog):
    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @commands.Cog.listener()
    async def on_member_join(self, member: discord.Member):
        """Envoie un DM de bienvenue et attribue le rôle Nouveau."""
        try:
            welcome_msg = config.WELCOME_MESSAGE.format(
                rules_channel=config.WELCOME_CHANNEL_ID,
                onboarding_channel=config.WELCOME_CHANNEL_ID,
                contrib_channel=config.WELCOME_CHANNEL_ID,
            )
            await member.send(welcome_msg)
        except discord.Forbidden:
            pass  # L'utilisateur a désactivé les DM

        # Attribution du rôle Nouveau
        guild = member.guild
        role = guild.get_role(config.NEW_MEMBER_ROLE_ID)
        if role:
            try:
                await member.add_roles(role, reason="Onboarding automatique")
            except discord.Forbidden:
                pass

        # Log dans le salon de bienvenue
        channel = guild.get_channel(config.WELCOME_CHANNEL_ID)
        if channel:
            embed = discord.Embed(
                description=f"👋 {member.mention} a rejoint le serveur ! Bienvenue !",
                color=discord.Color.green(),
            )
            embed.set_thumbnail(url=member.display_avatar.url)
            await channel.send(embed=embed)

    @commands.Cog.listener()
    async def on_raw_reaction_add(self, payload: discord.RawReactionActionEvent):
        """Attribution de rôles par réaction (dans le message d'onboarding)."""
        if payload.user_id == self.bot.user.id:
            return

        role_name = config.REACTION_ROLES.get(str(payload.emoji))
        if not role_name:
            return

        guild = self.bot.get_guild(payload.guild_id)
        if not guild:
            return

        role = discord.utils.get(guild.roles, name=role_name)
        member = guild.get_member(payload.user_id)
        if role and member:
            try:
                await member.add_roles(role, reason="Attribution par réaction")
            except discord.Forbidden:
                pass

    @commands.Cog.listener()
    async def on_raw_reaction_remove(self, payload: discord.RawReactionActionEvent):
        """Retrait de rôle si l'utilisateur enlève sa réaction."""
        if payload.user_id == self.bot.user.id:
            return

        role_name = config.REACTION_ROLES.get(str(payload.emoji))
        if not role_name:
            return

        guild = self.bot.get_guild(payload.guild_id)
        if not guild:
            return

        role = discord.utils.get(guild.roles, name=role_name)
        member = guild.get_member(payload.user_id)
        if role and member:
            try:
                await member.remove_roles(role, reason="Retrait par réaction")
            except discord.Forbidden:
                pass


# ---------------------------------------------------------------------------
# Cog : Sécurité (filtre anti-credential)
# ---------------------------------------------------------------------------

class SecurityCog(commands.Cog):
    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @commands.Cog.listener()
    async def on_message(self, message: discord.Message):
        """Supprime et alerte si un message contient des credentials."""
        if message.author.bot:
            return

        matches = contains_credentials(message.content)
        if not matches:
            return

        # Suppression immédiate
        try:
            await message.delete()
        except discord.Forbidden:
            return

        # MP à l'utilisateur
        try:
            embed = discord.Embed(
                title="🚨 Alerte sécurité",
                description=(
                    "Ton message a été supprimé automatiquement car il semblait "
                    "contenir des credentials (mot de passe, token, clé API).\n\n"
                    "**Ne partage jamais d'informations sensibles sur Discord.**\n\n"
                    "Si c'était une erreur de détection, contacte un modérateur."
                ),
                color=discord.Color.red(),
            )
            await message.author.send(embed=embed)
        except discord.Forbidden:
            pass

        # Alert dans le salon sécurité
        alert_channel = self.bot.get_channel(config.SECURITY_ALERT_CHANNEL_ID)
        if alert_channel:
            embed = discord.Embed(
                title="🚨 Credential leak détecté",
                description=f"Message supprimé de {message.author.mention} dans {message.channel.mention}",
                color=discord.Color.red(),
                timestamp=datetime.utcnow(),
            )
            embed.add_field(
                name="Contenu (extrait)",
                value=f"```\n{message.content[:500]}\n```",
                inline=False,
            )
            embed.set_footer(text=f"User ID: {message.author.id}")
            await alert_channel.send(embed=embed)


# ---------------------------------------------------------------------------
# Cog : Modération
# ---------------------------------------------------------------------------

class ModerationCog(commands.Cog):
    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @app_commands.command(name="warn", description="Avertit un membre")
    @app_commands.describe(member="Le membre à avertir", reason="Raison de l'avertissement")
    @app_commands.checks.has_permissions(kick_members=True)
    async def warn(self, interaction: discord.Interaction, member: discord.Member, reason: str):
        count = warnings_db.get(member.id, 0) + 1
        warnings_db[member.id] = count

        embed = create_mod_embed("Avertissement", interaction.user, member, reason)
        embed.add_field(name="Compteur", value=f"{count}/{config.MAX_WARNINGS_BEFORE_MUTE}", inline=True)
        await interaction.response.send_message(embed=embed)

        # Log modération
        mod_channel = self.bot.get_channel(config.MOD_LOG_CHANNEL_ID)
        if mod_channel:
            await mod_channel.send(embed=embed)

        # Auto-mute si seuil atteint
        if count >= config.MAX_WARNINGS_BEFORE_MUTE:
            mute_role = discord.utils.get(interaction.guild.roles, name="Muted")
            if mute_role:
                await member.add_roles(mute_role, reason=f"{count} warnings atteints")
                await interaction.followup.send(
                    f"🔇 {member.mention} a été mute pendant {config.MUTE_DURATION_MINUTES} minutes.",
                    ephemeral=True,
                )
                await asyncio.sleep(config.MUTE_DURATION_MINUTES * 60)
                await member.remove_roles(mute_role, reason="Fin du mute automatique")

    @app_commands.command(name="mute", description="Mute un membre pendant X minutes")
    @app_commands.describe(
        member="Le membre à mute",
        duration="Durée en minutes",
        reason="Raison du mute",
    )
    @app_commands.checks.has_permissions(kick_members=True)
    async def mute(
        self,
        interaction: discord.Interaction,
        member: discord.Member,
        duration: int,
        reason: str,
    ):
        mute_role = discord.utils.get(interaction.guild.roles, name="Muted")
        if not mute_role:
            await interaction.response.send_message(
                "❌ Le rôle `Muted` n'existe pas. Crée-le d'abord.", ephemeral=True
            )
            return

        await member.add_roles(mute_role, reason=reason)
        embed = create_mod_embed("Mute", interaction.user, member, reason, discord.Color.red())
        embed.add_field(name="Durée", value=f"{duration} min", inline=True)
        await interaction.response.send_message(embed=embed)

        mod_channel = self.bot.get_channel(config.MOD_LOG_CHANNEL_ID)
        if mod_channel:
            await mod_channel.send(embed=embed)

        await asyncio.sleep(duration * 60)
        await member.remove_roles(mute_role, reason="Fin du mute")

        unmute_embed = create_mod_embed(
            "Unmute (auto)", interaction.user, member, "Fin de la durée", discord.Color.green()
        )
        if mod_channel:
            await mod_channel.send(embed=unmute_embed)

    @app_commands.command(name="unmute", description="Dé-mute un membre")
    @app_commands.checks.has_permissions(kick_members=True)
    async def unmute(self, interaction: discord.Interaction, member: discord.Member):
        mute_role = discord.utils.get(interaction.guild.roles, name="Muted")
        if mute_role and mute_role in member.roles:
            await member.remove_roles(mute_role, reason="Dé-mute manuel")
            embed = create_mod_embed(
                "Unmute", interaction.user, member, "Dé-mute manuel", discord.Color.green()
            )
            await interaction.response.send_message(embed=embed)
        else:
            await interaction.response.send_message(
                "❌ Ce membre n'est pas mute.", ephemeral=True
            )

    @app_commands.command(name="clear", description="Supprime X messages dans le salon")
    @app_commands.describe(amount="Nombre de messages à supprimer (max 100)")
    @app_commands.checks.has_permissions(manage_messages=True)
    async def clear(self, interaction: discord.Interaction, amount: int):
        if amount < 1 or amount > 100:
            await interaction.response.send_message(
                "❌ Le nombre doit être entre 1 et 100.", ephemeral=True
            )
            return
        await interaction.response.defer(ephemeral=True)
        deleted = await interaction.channel.purge(limit=amount)
        await interaction.followup.send(f"🗑️ {len(deleted)} message(s) supprimé(s).", ephemeral=True)


# ---------------------------------------------------------------------------
# Cog : Commandes utilitaires
# ---------------------------------------------------------------------------

class UtilityCog(commands.Cog):
    def __init__(self, bot: commands.Bot):
        self.bot = bot
        self.session: Optional[aiohttp.ClientSession] = None

    async def cog_load(self):
        self.session = aiohttp.ClientSession()

    async def cog_unload(self):
        if self.session:
            await self.session.close()

    @app_commands.command(name="help", description="Affiche l'aide du bot")
    async def help_command(self, interaction: discord.Interaction):
        embed = discord.Embed(
            title="🤖 Talaxie Bot — Aide",
            description="Commandes disponibles pour la communauté Talaxie",
            color=discord.Color.blue(),
        )
        embed.add_field(
            name="📚 Utilitaires",
            value=(
                "`/help` — Cette aide\n"
                "`/doc <sujet>` — Lien vers la documentation\n"
                "`/issue <mot-clé>` — Rechercher une issue GitHub\n"
                "`/roadmap` — Voir la roadmap du projet"
            ),
            inline=False,
        )
        embed.add_field(
            name="🔧 Modération",
            value=(
                "`/warn <membre> <raison>` — Avertir un membre\n"
                "`/mute <membre> <durée> <raison>` — Mute temporaire\n"
                "`/unmute <membre>` — Dé-mute\n"
                "`/clear <nombre>` — Supprimer des messages"
            ),
            inline=False,
        )
        embed.set_footer(text="Bot Talaxie Community v1.0")
        await interaction.response.send_message(embed=embed)

    @app_commands.command(name="doc", description="Retourne un lien vers la documentation")
    @app_commands.describe(topic="Sujet recherché (ex: installation, composants, migration)")
    async def doc(self, interaction: discord.Interaction, topic: Optional[str] = None):
        if topic:
            url = f"{config.DOCS_URL}/search?q={topic.replace(' ', '+')}"
            await interaction.response.send_message(f"📖 Documentation sur **{topic}** : {url}")
        else:
            await interaction.response.send_message(f"📖 Documentation Talaxie : {config.DOCS_URL}")

    @app_commands.command(name="issue", description="Recherche une issue GitHub ouverte")
    @app_commands.describe(keyword="Mot-clé à rechercher")
    async def issue(self, interaction: discord.Interaction, keyword: str):
        if not self.session:
            await interaction.response.send_message("❌ Session HTTP non initialisée.", ephemeral=True)
            return

        url = f"https://api.github.com/search/issues?q=repo:{config.GITHUB_REPO}+{keyword.replace(' ', '+')}+state:open&per_page=5"
        async with self.session.get(url) as resp:
            if resp.status != 200:
                await interaction.response.send_message(
                    "❌ Erreur lors de la recherche GitHub.", ephemeral=True
                )
                return
            data = await resp.json()

        if not data.get("items"):
            await interaction.response.send_message(
                f"🔍 Aucune issue trouvée pour `{keyword}`.\n"
                f"[Créer une nouvelle issue](https://github.com/{config.GITHUB_REPO}/issues/new)",
                ephemeral=True,
            )
            return

        embed = discord.Embed(
            title=f"🔍 Issues GitHub — {keyword}",
            url=f"https://github.com/{config.GITHUB_REPO}/issues?q=is%3Aissue+is%3Aopen+{keyword.replace(' ', '+')}",
            color=discord.Color.blue(),
        )
        for item in data["items"][:5]:
            labels = ", ".join([l["name"] for l in item.get("labels", [])]) or "aucun"
            embed.add_field(
                name=f"#{item['number']} {item['title']}",
                value=f"[Voir]({item['html_url']}) — Labels : {labels}",
                inline=False,
            )
        await interaction.response.send_message(embed=embed)

    @app_commands.command(name="roadmap", description="Affiche le lien vers la roadmap")
    async def roadmap(self, interaction: discord.Interaction):
        url = f"https://github.com/{config.GITHUB_REPO}/projects"
        embed = discord.Embed(
            title="📊 Roadmap Talaxie",
            description="Suivi des développements et fonctionnalités planifiées.",
            url=url,
            color=discord.Color.purple(),
        )
        embed.set_footer(text="Vote et commente sur GitHub Projects")
        await interaction.response.send_message(embed=embed)


# ---------------------------------------------------------------------------
# Cog : Webhook Parser (GitHub / CI)
# ---------------------------------------------------------------------------

class WebhookCog(commands.Cog):
    """
    Améliore le rendu des webhooks natifs Discord en ajoutant des réactions
    ou des commentaires automatiques. Les webhooks eux-mêmes sont configurés
    côté GitHub (Settings > Webhooks) et pointent vers le salon #github-feed.
    """

    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @commands.Cog.listener()
    async def on_message(self, message: discord.Message):
        """Ajoute une réaction ✅ aux messages de webhook annonçant une PR mergée."""
        if message.author.bot and message.webhook_id:
            # Détection simple : message webhook contenant "merged"
            if "merged" in message.content.lower() or any(
                "merged" in str(e.title).lower()
                for e in message.embeds if e.title
            ):
                try:
                    await message.add_reaction("🎉")
                except discord.Forbidden:
                    pass


# ---------------------------------------------------------------------------
# Lancement
# ---------------------------------------------------------------------------

@bot.event
async def on_ready():
    print(f"✅ Connecté en tant que {bot.user} (ID: {bot.user.id})")
    print(f"🌐 Guild cible : {config.GUILD_ID}")
    print("------")

    # Synchronisation des commandes slash
    try:
        guild = discord.Object(id=config.GUILD_ID)
        synced = await bot.tree.sync(guild=guild)
        print(f"🔧 {len(synced)} commande(s) slash synchronisée(s)")
    except Exception as e:
        print(f"⚠️ Erreur synchronisation commandes : {e}")


async def main():
    async with bot:
        await bot.add_cog(OnboardingCog(bot))
        await bot.add_cog(SecurityCog(bot))
        await bot.add_cog(ModerationCog(bot))
        await bot.add_cog(UtilityCog(bot))
        await bot.add_cog(WebhookCog(bot))
        await bot.start(config.DISCORD_TOKEN)


if __name__ == "__main__":
    asyncio.run(main())
