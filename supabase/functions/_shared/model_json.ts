// Lecture robuste du JSON renvoyé par un modèle quand il contient du LaTeX.
//
// Les modèles écrivent souvent « \frac » avec UNE seule barre dans une chaîne JSON. Deux dégâts :
//   1. « \f », « \t », « \b », « \n », « \r » sont des échappements JSON valides : JSON.parse
//      accepte, mais « \frac » devient un saut de page suivi de « rac », « \times » une tabulation
//      suivie de « imes », « \neq » un retour à la ligne suivi de « eq »… Le corrigé enregistré est
//      faux sans que personne ne le voie.
//   2. « \Delta », « \sqrt », « \in »… ne sont pas des échappements valides : JSON.parse échoue et
//      toute la génération est perdue.
// parseModelJson double ces barres AVANT l'analyse, sans toucher aux échappements légitimes
// (\" \\ \/ \uXXXX, et \n \t réellement voulus devant un caractère qui n'ouvre pas une commande).

// Commandes LaTeX qui commencent par une lettre d'échappement JSON valide (f, t, b, n, r).
const LATEX_AFTER_VALID_ESCAPE =
  /\\(?=(?:frac|forall|flat|times|text|textbf|theta|tau|tan|tilde|to\b|top|triangle|beta|begin|bar|binom|bmod|bot|boxed|bullet|bigcup|bigcap|neq|nabla|nu\b|not|ne\b|newline|nolimits|right|rho|rangle|rceil|rfloor|rm\b|Rightarrow))/g;

export function repairLatexEscapes(text: string): string {
  let out = "";
  let inString = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (!inString) {
      if (ch === '"') inString = true;
      out += ch;
      continue;
    }
    if (ch === '"') {
      inString = false;
      out += ch;
      continue;
    }
    if (ch !== "\\") {
      out += ch;
      continue;
    }
    const next = text[i + 1] ?? "";
    // Échappements toujours légitimes : on les recopie tels quels.
    if (next === '"' || next === "\\" || next === "/" || (next === "u" && /^[0-9a-fA-F]{4}$/.test(text.slice(i + 2, i + 6)))) {
      out += ch + next;
      i++;
      continue;
    }
    // \f \t \b \n \r : légitime, sauf s'il ouvre en réalité une commande LaTeX.
    if ("ftbnr".includes(next)) {
      LATEX_AFTER_VALID_ESCAPE.lastIndex = 0;
      const rest = text.slice(i, i + 16);
      if (LATEX_AFTER_VALID_ESCAPE.test(rest)) {
        out += "\\\\";
        continue;
      }
      out += ch + next;
      i++;
      continue;
    }
    // Toute autre barre (\Delta, \sqrt, \in, \{ …) : invalide en JSON → doublée.
    out += "\\\\";
  }
  return out;
}

/** Retire un éventuel bloc ```json … ``` puis analyse en réparant les barres du LaTeX. */
export function parseModelJson<T = unknown>(raw: string): T {
  let text = raw.trim();
  const fence = text.match(/^```(?:json)?\s*([\s\S]*?)\s*```$/i);
  if (fence) text = fence[1];
  try {
    const direct = JSON.parse(text) as T;
    // Analyse réussie : vérifier qu'aucune commande LaTeX n'a été avalée par un échappement.
    if (!/[\f\b\t\r\n](rac|imes|ext|heta|eta|egin|eq|abla|ight|ho\b|orall)/.test(JSON.stringify(direct).replace(/\\[fbtrn]/g, (m) => ({ "\\f": "\f", "\\b": "\b", "\\t": "\t", "\\r": "\r", "\\n": "\n" } as Record<string, string>)[m]))) {
      return direct;
    }
  } catch (_) {
    // on tente la réparation ci-dessous
  }
  return JSON.parse(repairLatexEscapes(text)) as T;
}
