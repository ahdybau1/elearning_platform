"""Lit le registre réel (IA-001, migration 55) : quel agent existe, quelle Edge Function l'exécute
vraiment aujourd'hui. La Gateway ne fait AUCUNE hypothèse en dur sur le mapping agent -> implémentation
— elle interroge la même table que l'écran Admin `ai_agent_registry_screen.dart`.
"""
import httpx
from fastapi import HTTPException
from .config import settings

_service_headers = {
    "Authorization": f"Bearer {settings.supabase_service_role_key}",
    "apikey": settings.supabase_service_role_key,
}


async def get_agent_version(agent_id: str) -> dict:
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(
            f"{settings.rest_url}/ai_agents",
            params={
                "agent_id": f"eq.{agent_id}",
                "select": "id,agent_id,name,status,ai_agent_versions(id,version,edge_function_name,status,input_schema,output_schema)",
            },
            headers=_service_headers,
        )
    if res.status_code != 200 or not res.json():
        raise HTTPException(status_code=404, detail=f"Agent inconnu du registre : {agent_id}")
    agent = res.json()[0]
    if agent["status"] != "active":
        raise HTTPException(status_code=409, detail=f"Agent '{agent_id}' n'est pas actif (status={agent['status']}).")
    versions = [v for v in agent["ai_agent_versions"] if v["status"] == "production"]
    if not versions:
        raise HTTPException(status_code=409, detail=f"Aucune version 'production' pour l'agent '{agent_id}'.")
    version = versions[0]
    if not version.get("edge_function_name"):
        raise HTTPException(status_code=501, detail=f"Agent '{agent_id}' n'a pas encore d'implémentation reliée.")
    return {"agent_name": agent["name"], **version}
