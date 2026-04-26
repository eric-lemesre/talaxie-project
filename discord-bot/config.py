"""
Configuration du bot Talaxie.
Les variables sensibles sont chargées depuis le fichier .env
"""
import os
from dotenv import load_dotenv

load_dotenv()

# Discord
DISCORD_TOKEN = os.getenv("DISCORD_TOKEN")
GUILD_ID = int(os.getenv("GUILD_ID", "0"))

# Salons
WELCOME_CHANNEL_ID = int(os.getenv("WELCOME_CHANNEL_ID", "0"))
MOD_LOG_CHANNEL_ID = int(os.getenv("MOD_LOG_CHANNEL_ID", "0"))
SECURITY_ALERT_CHANNEL_ID = int(os.getenv("SECURITY_ALERT_CHANNEL_ID", "0"))

# Rôles
NEW_MEMBER_ROLE_ID = int(os.getenv("NEW_MEMBER_ROLE_ID", "0"))

# Intégrations externes
GITHUB_REPO = os.getenv("GITHUB_REPO", "eric-lemesre/Talaxie")
DOCS_URL = os.getenv("DOCS_URL", "https://docs.talaxie.org")

# Règles de modération
MAX_WARNINGS_BEFORE_MUTE = 3
MUTE_DURATION_MINUTES = 60

# Patterns de détection de credentials (filtre anti-fuite)
CREDENTIAL_PATTERNS = [
    r"(?i)(api[_-]?key\s*[:=]\s*)['\"]?[a-z0-9]{16,}['\"]?",
    r"(?i)(password|passwd|pwd)\s*[:=]\s*['\"]?[^\s'\"]{4,}['\"]?",
    r"(?i)(token|secret)\s*[:=]\s*['\"]?[a-z0-9\-_]{16,}['\"]?",
    r"(?i)(jdbc:mysql://[^:]+:[^@]+@)",
    r"(?i)(ssh-rsa\s+AAAA[0-9A-Za-z+/]+=)",
    r"(?i)(BEGIN\s+(RSA|OPENSSH|DSA|EC)\s+PRIVATE\s+KEY)",
    r"(?i)(aws_access_key_id|aws_secret_access_key)\s*[:=]\s*['\"]?[A-Z0-9/+=]{16,}['\"]?",
    r"ghp_[a-zA-Z0-9]{36}",
    r"glpat-[a-zA-Z0-9\-]{20}",
]

# Rôles thématiques disponibles via réaction (emoji -> nom du rôle)
REACTION_ROLES = {
    "🟦": "Java Dev",
    "🟩": "Data Engineer",
    "🟥": "Admin Sys",
    "🟨": "Traducteur",
    "🟪": "Bug Hunter",
    "⬜": "Mentor",
}

# Messages
WELCOME_MESSAGE = """
👋 Bienvenue sur **Talaxie Community** !

Tu viens de rejoindre le serveur du fork communautaire de Talend Open Studio.

📌 **Pour bien démarrer :**
1. Lis le règlement dans <#{rules_channel}>
2. Choisis tes rôles dans <#{onboarding_channel}>
3. Pose ta première question dans le salon adapté

🤝 **Tu veux contribuer ?** Va dans <#{contrib_channel}> et consulte les "good first issues".

*Ce message est automatique — un humain te répondra bientôt si tu as des questions !*
"""
