-- Corrige une corruption d'encodage réelle introduite par un bug de l'outil d'exécution SQL
-- utilisé pendant cette session (le script auxiliaire qui envoie le SQL à l'API Management lisait
-- l'entrée standard avec l'encodage par défaut de Python sous Windows au lieu de forcer l'UTF-8,
-- transformant chaque caractère accentué en deux caractères mal réinterprétés — ex. "é" devenait
-- "Ã©"). Confirmé par comparaison longueur en caractères vs en octets (jamais un simple artefact
-- d'affichage, vérifié précisément avant d'agir). Corrigé dans l'outil lui-même (pas un fichier du
-- dépôt) ; cette migration ne fait que réparer les deux migrations déjà appliquées pendant qu'il
-- était cassé (87_gamification.sql, 88_cameroon_academic_tree.sql).
--
-- Réversion exacte : un premier essai avec LATIN1 a échoué sur "Ê" (0xC3 0x8A en UTF-8) — l'octet
-- 0x8A n'existe pas en LATIN1 (control C1) mais correspond à "Š" en WIN1252 (Windows-1252), ce qui
-- prouve que l'encodage réellement en cause était WIN1252, pas LATIN1 (les deux ne diffèrent que
-- sur la plage 0x80-0x9F). `convert_from(convert_to(x,'WIN1252'),'UTF8')` inverse exactement
-- l'opération, vérifié ligne par ligne (longueur en caractères et en octets, y compris le cas "Ê")
-- avant application.

UPDATE academic_nodes
SET name = convert_from(convert_to(name, 'WIN1252'), 'UTF8')
WHERE name LIKE '%Ã%';

UPDATE badge_definitions
SET name = convert_from(convert_to(name, 'WIN1252'), 'UTF8'),
    description = convert_from(convert_to(description, 'WIN1252'), 'UTF8')
WHERE name LIKE '%Ã%' OR description LIKE '%Ã%';
