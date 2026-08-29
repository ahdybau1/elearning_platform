"""Auth (IA-002 : « Auth, permissions... »). Vérifie le JWT Supabase du client en appelant
GET /auth/v1/user — pas de réimplémentation de la vérification de signature ici : Supabase fait déjà
cette vérification de façon fiable, la dupliquer serait une source d'erreur inutile.
"""
import httpx
from fastapi import Header, HTTPException
from .config import settings


class AuthenticatedUser:
    def __init__(self, auth_user_id: str, email: str | None, raw_token: str):
        self.auth_user_id = auth_user_id
        self.email = email
        self.raw_token = raw_token
        self.is_admin: bool = False
        self.admin_role: str | None = None
        self.account_id: str | None = None


async def get_current_user(authorization: str = Header(...)) -> AuthenticatedUser:
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Authorization: Bearer <token> requis.")
    token = authorization.removeprefix("Bearer ").strip()

    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(
            f"{settings.auth_url}/user",
            headers={"Authorization": f"Bearer {token}", "apikey": settings.supabase_anon_key},
        )
    if res.status_code != 200:
        raise HTTPException(status_code=401, detail="Session invalide ou expirée.")

    data = res.json()
    user = AuthenticatedUser(auth_user_id=data["id"], email=data.get("email"), raw_token=token)

    # Permissions minimales (IA-002) : distinguer admin vs élève/parent en interrogeant les tables
    # réelles — mêmes tables que le reste du projet (admin_users.auth_user_id, accounts.auth_user_id).
    async with httpx.AsyncClient(timeout=10.0) as client:
        admin_res = await client.get(
            f"{settings.rest_url}/admin_users",
            params={"auth_user_id": f"eq.{user.auth_user_id}", "is_active": "eq.true", "select": "role"},
            headers={
                "Authorization": f"Bearer {settings.supabase_service_role_key}",
                "apikey": settings.supabase_service_role_key,
            },
        )
    if admin_res.status_code == 200 and admin_res.json():
        user.is_admin = True
        user.admin_role = admin_res.json()[0]["role"]
    else:
        async with httpx.AsyncClient(timeout=10.0) as client:
            acct_res = await client.get(
                f"{settings.rest_url}/accounts",
                params={"auth_user_id": f"eq.{user.auth_user_id}", "select": "id"},
                headers={
                    "Authorization": f"Bearer {settings.supabase_service_role_key}",
                    "apikey": settings.supabase_service_role_key,
                },
            )
        if acct_res.status_code == 200 and acct_res.json():
            user.account_id = acct_res.json()[0]["id"]

    return user


async def verify_profile_access(user: AuthenticatedUser, profile_id: str | None) -> None:
    """Un profil élève appartient à un seul compte — jamais interrogeable pour un autre compte
    authentifié, même via un `profile_id` fourni tel quel dans le corps d'une requête. Avant IA-007,
    rien ne vérifiait ce lien dans `invoke_agent` (un `profile_id` arbitraire était accepté tel quel,
    y compris pour `record_usage` — IA-006). Nécessaire dès maintenant : IA-007 lit le Student Model
    (données pédagogiques sur un profil, potentiellement mineur) à partir de ce même `profile_id`."""
    if not profile_id or user.is_admin:
        return
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(
            f"{settings.rest_url}/profiles",
            params={"id": f"eq.{profile_id}", "select": "account_id"},
            headers={
                "Authorization": f"Bearer {settings.supabase_service_role_key}",
                "apikey": settings.supabase_service_role_key,
            },
        )
    rows = res.json() if res.status_code == 200 else []
    if not rows or rows[0].get("account_id") != user.account_id:
        raise HTTPException(status_code=403, detail="profile_id ne correspond pas au compte authentifié.")
