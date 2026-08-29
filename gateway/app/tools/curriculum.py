"""Tool curriculum (§12). Lit l'arbre académique réel (`academic_nodes`, table générique
pays/section/type/classe/série — voir docs/cahier_des_charges.md §36.2) via des requêtes PostgREST
filtrées par ID, jamais du SQL construit dynamiquement.
"""
import httpx
from ..config import settings

_service_headers = {
    "Authorization": f"Bearer {settings.supabase_service_role_key}",
    "apikey": settings.supabase_service_role_key,
}


class CurriculumToolError(ValueError):
    pass


async def get_curriculum_context(class_node_id: str) -> dict:
    """Remonte la chaîne parent_id jusqu'à la racine (pays) — profondeur variable selon le pays
    (§35 du cahier maître), donc pas de nombre de niveaux supposé en dur."""
    path: list[dict] = []
    current_id: str | None = class_node_id
    seen: set[str] = set()

    async with httpx.AsyncClient(timeout=10.0) as client:
        while current_id:
            if current_id in seen:
                raise CurriculumToolError("Cycle détecté dans academic_nodes — arbre corrompu.")
            seen.add(current_id)

            res = await client.get(
                f"{settings.rest_url}/academic_nodes",
                params={"id": f"eq.{current_id}", "select": "id,parent_id,node_type,name"},
                headers=_service_headers,
            )
            if res.status_code != 200 or not res.json():
                if not path:
                    raise CurriculumToolError(f"class_node_id inconnu : {class_node_id}")
                break
            node = res.json()[0]
            path.append({"id": node["id"], "node_type": node["node_type"], "name": node["name"]})
            current_id = node.get("parent_id")

    path.reverse()  # racine (pays) en premier
    return {"path": path}
