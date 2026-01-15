# Plan de Tests - Extensions RAT

Ce document liste tous les comportements à tester pour chaque fonctionnalité, organisés par passe de compilation.

## Structure des Tests

Les tests sont organisés par **passe**, pas par fonctionnalité :
- `tests/gestion_id/` - Passe TDS (résolution identifiants)
- `tests/type/` - Passe de typage
- `tests/tam/` - Génération de code + exécution

## 1. PROCÉDURES

### TDS - Comportements attendus
1. Déclaration procédure simple void
2. Procédure avec paramètres
3. Appel depuis main et depuis fonction

### TDS - Erreurs à détecter
1. Appel procédure inexistante → `IdentifiantNonDeclare`
2. Utilisation variable comme procédure → `MauvaiseUtilisationIdentifiant`

### Type - Comportements attendus
1. Return void dans procédure
2. Return conditionnel
3. Bons types de paramètres

### Type - Erreurs à détecter
1. Return avec valeur dans procédure → `TypeInattendu`
2. Return sans valeur dans fonction → `TypeInattendu`
3. Utiliser résultat procédure → `TypeInattendu`
4. Mauvais types paramètres → `TypesParametresInattendus`

### TAM - Tests d'exécution
1. Procédure simple → output attendu
2. Avec paramètres → output attendu
3. Return anticipé → output attendu

## 2. ENUMS

### TDS - Comportements attendus
1. Déclaration enum simple
2. Multiples enums sans conflit
3. Enum dans fonction

### TDS - Erreurs à détecter
1. Nom type dupliqué → `DoubleDeclaration`
2. Valeur dans deux enums → `DoubleDeclaration`
3. Valeur inexistante → `IdentifiantNonDeclare`

### Type - Comportements attendus
1. Affectation entre valeurs même enum
2. Égalité entre valeurs même enum
3. Enum comme paramètre/retour

### Type - Erreurs à détecter
1. Affectation entre enums différents → `TypeInattendu`
2. Comparaison enums différents → `TypeBinaireInattendu`
3. Enum à int ou int à enum → `TypeInattendu`
4. Opérations arithmétiques → `TypeBinaireInattendu`

### TAM - Tests d'exécution
1. Affichage valeurs (0,1,2...)
2. Test égalité (page 6 sujet)
3. Conditionnelle sur enum

## 3. POINTEURS

### TDS - Comportements attendus
1. Déclaration pointeur
2. Adresse de variable
3. Allocation dynamique
4. Déréférencement

### TDS - Erreurs à détecter
1. Adresse de constante → `MauvaiseUtilisationIdentifiant`
2. Adresse de fonction → `MauvaiseUtilisationIdentifiant`
3. Adresse identifiant inexistant → `IdentifiantNonDeclare`

### Type - Comportements attendus
1. Null compatible tous pointeurs
2. New retourne bon type
3. Adresse retourne pointeur
4. Déréférencement lecture/écriture
5. Pointeurs de pointeurs

### Type - Erreurs à détecter
1. Déréférencement non-pointeur → erreur type
2. Affectation pointeurs incompatibles → `TypeInattendu`
3. Déréférencement mauvais type → `TypeInattendu`

### TAM - Tests d'exécution
1. Allocation et déréférencement (page 3)
2. Adresse de variable
3. Modification via pointeur
4. Pointeurs multiples

## 4. PASSAGE PAR RÉFÉRENCE

### TDS - Comportements attendus
1. Fonction avec paramètre ref
2. Mix ref/non-ref
3. Passage variable en ref

### TDS - Erreurs à détecter
1. Passage constante en ref → `MauvaiseUtilisationIdentifiant`
2. Passage identifiant inexistant → `IdentifiantNonDeclare`

### Type - Comportements attendus
1. Ref avec type compatible
2. Mix ref/non-ref
3. Ref pointeur
4. Ref enum

### Type - Erreurs à détecter
1. Ref type incompatible → `TypesParametresInattendus`
2. Nombre paramètres incorrect → `TypesParametresInattendus`

### TAM - Tests d'exécution
1. Modification simple via ref
2. Swap (page 4 sujet)
3. Comparaison ref vs non-ref
4. Enchaînement appels (page 5)

## 5. INTÉGRATION

### TAM - Tests combinés
1. Enum + Pointeurs
2. Ref + Pointeurs
3. Procédures + Enums
4. Programme complet page 7