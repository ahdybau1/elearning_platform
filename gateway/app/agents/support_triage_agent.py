"""IA-013 "Operations" — SupportTriageAgent (AIA-AGT-022).

Mission du cahier : « Classer demandes support, détecter urgence, rechercher solutions documentées,
router vers la bonne équipe. » Sortie : « category, priority, suggested_response, routing_target,
required_context. » Règle : « Minimisation des données ; pas de demande de secrets ; aucune action
sensible sans procédure support autorisée. »

Décision : agent déterministe par mots-clés, pas de LLM — cohérent avec la préférence du cahier pour
un moteur mécanique quand il suffit (même principe que RecommendationAgent/DiagnosticAgent).
`category` est déjà choisie par le demandeur à la création du ticket (`support_tickets.category`,
contrainte CHECK réelle) — cet agent ne la réinvente pas, il calcule PRIORITÉ et ROUTAGE, que rien ne
calcule aujourd'hui. `suggested_response` reste `None` : aucune base de solutions documentées
n'existe sur ce projet — une réponse inventée serait pire qu'aucune réponse. N'écrit JAMAIS
`assigned_to` lui-même : une suggestion affichée à l'admin, jamais une décision prise à sa place.
"""
import httpx
from ..config import settings

_service_headers = {
    "Authorization": f"Bearer {settings.supabase_service_role_key}",
    "apikey": settings.supabase_service_role_key,
    "Content-Type": "application/json",
}

_URGENT_KEYWORDS = (
    "urgent", "bloqué", "bloquée", "impossible de payer", "piraté", "piratée",
    "compte suspendu", "perdu mon accès", "arnaque", "fraude", "ne fonctionne plus du tout",
)
_ROUTING_BY_CATEGORY = {
    "paiement": "equipe_facturation",
    "technique": "equipe_technique",
    "contenu": "equipe_pedagogique",
    "autre": "equipe_support_generale",
}


class SupportTriageError(ValueError):
    pass


def _detect_priority(subject: str, description: str) -> str:
    text = f"{subject} {description}".lower()
    return "haute" if any(keyword in text for keyword in _URGENT_KEYWORDS) else "normale"


async def triage_ticket(ticket_id: str) -> dict:
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(
            f"{settings.rest_url}/support_tickets",
            params={"id": f"eq.{ticket_id}", "select": "id,category,subject,description,requester_type"},
            headers=_service_headers,
        )
    rows = res.json() if res.status_code == 200 else []
    if not rows:
        raise SupportTriageError(f"Ticket introuvable : {ticket_id}")
    ticket = rows[0]

    return {
        "ticket_id": ticket_id,
        "category": ticket["category"],
        "priority": _detect_priority(ticket["subject"], ticket["description"]),
        "routing_target": _ROUTING_BY_CATEGORY.get(ticket["category"], "equipe_support_generale"),
        "suggested_response": None,
        "required_context": [],
    }
