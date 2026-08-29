"""IA-003 "Tool Gateway" (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §22, §12) : outils typés, allowlistés,
JAMAIS d'accès SQL arbitraire — chaque tool est une fonction Python à paramètres fixes, appelant
PostgREST via des requêtes filtrées (jamais une chaîne SQL construite dynamiquement) ou un calcul
purement local (SymPy).

Catégories couvertes ici : curriculum, content, math — conformes au §12 du cahier. RAG n'est PAS
inclus : le pipeline d'ingestion (IA-004 partie 2) n'existe pas encore, un tool RAG interrogerait des
tables vides aujourd'hui, ce qui serait un faux outil.
"""
from .registry import TOOL_REGISTRY

__all__ = ["TOOL_REGISTRY"]
