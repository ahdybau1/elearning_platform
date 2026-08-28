"""Configuration du Sovereign AI Gateway (IA-002 — voir docs/CAHIER_DES_CHARGES_AGENTS_IA.md §3, §22).

Chargée depuis gateway/.env (jamais commité — voir .gitignore). Mêmes identifiants Supabase que le
reste du projet (student_app/admin_app/.env, secrets des Edge Functions).
"""
import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent.parent / ".env")


class Settings:
    supabase_url: str = os.environ["SUPABASE_URL"]
    supabase_anon_key: str = os.environ["SUPABASE_ANON_KEY"]
    supabase_service_role_key: str = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
    port: int = int(os.environ.get("GATEWAY_PORT", "8000"))

    @property
    def rest_url(self) -> str:
        return f"{self.supabase_url}/rest/v1"

    @property
    def functions_url(self) -> str:
        return f"{self.supabase_url}/functions/v1"

    @property
    def auth_url(self) -> str:
        return f"{self.supabase_url}/auth/v1"


settings = Settings()
