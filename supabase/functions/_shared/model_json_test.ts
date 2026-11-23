// deno test supabase/functions/_shared/model_json_test.ts
function assertEquals(a: unknown, b: unknown) {
  if (JSON.stringify(a) !== JSON.stringify(b)) {
    throw new Error(`attendu ${JSON.stringify(b)}, obtenu ${JSON.stringify(a)}`);
  }
}
import { parseModelJson } from "./model_json.ts";

Deno.test("\\frac à une barre n'est plus avalé en saut de page", () => {
  const r = parseModelJson<{ s: string }>('{"s": "$\\frac{1}{2}$"}');
  assertEquals(r.s, "$\\frac{1}{2}$");
});
Deno.test("\\times et \\neq conservés", () => {
  const r = parseModelJson<{ s: string }>('{"s": "$a \\times b \\neq 0$"}');
  assertEquals(r.s, "$a \\times b \\neq 0$");
});
Deno.test("\\Delta (échappement invalide) ne fait plus échouer l'analyse", () => {
  const r = parseModelJson<{ s: string }>('{"s": "$\\Delta = b^2 - 4ac$"}');
  assertEquals(r.s, "$\\Delta = b^2 - 4ac$");
});
Deno.test("JSON déjà correct inchangé, vrais retours à la ligne conservés", () => {
  const r = parseModelJson<{ s: string }>('{"s": "$\\\\frac{1}{2}$\\nLigne 2"}');
  assertEquals(r.s, "$\\frac{1}{2}$\nLigne 2");
});
Deno.test("bloc ```json retiré", () => {
  const r = parseModelJson<{ a: number }>('```json\n{"a": 1}\n```');
  assertEquals(r.a, 1);
});
