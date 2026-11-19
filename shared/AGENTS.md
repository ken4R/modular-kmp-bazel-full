# shared/ : logique commune en Kotlin Multiplatform

Tout ce que les deux applications ont en commun vit ici, et y est testé une seule fois. Construit par Bazel, pour la JVM avec rules_kotlin et pour iOS avec les règles Kotlin/Native maison de `bazel/kotlin_native`. Les règles communes du dépôt sont dans `AGENTS.md`, à la racine.

## Modules

- `core/<nom>` : brique commune (session, réseau, modèle). Macro `kmp_core`.
- `feature/<nom>` : logique d'un écran ou d'un parcours. Macro `kmp_feature`, qui ajoute le `ViewModel` multiplateforme d'AndroidX.
- `umbrella` : le seul module qui produit le framework iOS `Shared`. Macro `kmp_umbrella`. `SharedGraph` y assemble les dépendances à la main, en attendant le choix d'une bibliothèque d'injection.

Un module garde la disposition d'un module Gradle :

```
BUILD.bazel                      un appel de macro
src/commonMain/kotlin/**/*.kt    code pour Android et iOS
src/commonTest/kotlin/**/*.kt    tests, lancés sur la JVM et dans un simulateur iOS
src/iosMain/kotlin/**/*.kt       facultatif : code pour iOS seulement
src/iosTest/kotlin/**/*.kt       facultatif : tests pour iOS seulement
```

```starlark
load("//shared:kmp_module.bzl", "kmp_feature")

kmp_feature(
    name = "login",
    deps = ["//shared/core/session"],
)
```

Chaque macro déclare, pour un module `<nom>` :

| Cible | Contenu |
|---|---|
| `<nom>` | `commonMain` sur la JVM, pour Android |
| `<nom>_native` | `commonMain` et `iosMain`, une klib par cible Kotlin/Native (`ios_arm64`, `ios_simulator_arm64`) |
| `<nom>_test` | les tests JVM de `commonTest` |
| `<nom>_native_test` | `commonTest` et `iosTest` dans un simulateur iOS, sur un Mac Apple silicon seulement |

Le nom du module est le nom de son dossier. Le paquet Kotlin suit le chemin : `shared/feature/login` est `com.example.modular.shared.feature.login`.

## Écrire la logique d'une feature

Le modèle est `feature/login`.

- Un `ViewModel` expose `state: StateFlow<XxxUiState>`, `events: Flow<XxxEvent>` et des fonctions d'action qui ne renvoient rien.
- `XxxUiState` est une `data class` immuable. Ses valeurs par défaut décrivent l'état initial.
- `XxxEvent` est une `sealed interface` d'intentions de navigation, livrées une seule fois. Le code partagé dit ce qui s'est passé, chaque application décide où aller.
- Un échec métier est une valeur (`sealed interface`, `enum`), pas une exception. Le texte affiché est choisi par chaque plateforme.
- Une feature dépend des interfaces de `core`, jamais d'une implémentation.

## Ce que Swift voit

Il n'y a pas de SKIE : Swift lit l'en-tête Objective-C que le compilateur Kotlin/Native écrit.

- L'API explicite est active : chaque déclaration donne sa visibilité, et ce qui est `public` est une API. Ne rendre public que ce dont un écran a besoin.
- Un module garde ses noms Kotlin en Swift s'il est listé dans `export_to_swift`, dans `umbrella/BUILD.bazel`. Les autres gardent un préfixe : `StateFlow` devient `Kotlinx_coroutines_coreStateFlow`.
- Les génériques d'une interface disparaissent : `state.value` est un `Any?`. `Observed`, dans `ios/SharedKit`, redonne le type de l'état, et `values(of:)` lit un `Flow` comme une séquence asynchrone. Les deux s'appuient sur `subscribe`, dans `umbrella/src/iosMain`.
- Une `sealed interface` devient un protocole et ses cas des classes : un `switch` en Swift teste les types et a besoin d'un `default`. Un `enum` Kotlin devient une classe, `LoginError.invalidEmail`, avec le même `default`.
- Les entrées d'un `enum` s'écrivent en majuscules : `INVALID_EMAIL` devient `invalidEmail` en Swift. Le compilateur met chaque segment entre `_` en minuscules, et une entrée écrite `InvalidEmail` deviendrait `invalidemail`.
- Une fonction `suspend` devient une fonction `async throws`. Une lambda Kotlin qui renvoie `Unit` est une closure Swift qui ne renvoie rien. Une fonction de premier niveau vit dans la classe `<Fichier>Kt`.
- Les valeurs par défaut des paramètres n'existent pas en Swift : il passe tous les arguments.
- Après un changement visible depuis Swift, `bazel test //ios/...` reconstruit le framework de lui-même. Relancer `tools/shared/sync` pour les paquets Swift. Sur macOS ou par la CI.

## Tests

- Dans `commonTest`, avec `kotlin.test` et `kotlinx-coroutines-test`. Voir `LoginViewModelTest`.
- Un fichier de test contient une classe du même nom, dans le paquet de son dossier : `src/commonTest/kotlin/com/example/FooTest.kt` contient `com.example.FooTest`. La macro en déduit la suite JUnit du module, qui lance toutes les classes dont le nom finit par `Test`.
- Sur JVM : `bazel test //shared/feature/login:login_test`.
- Dans un simulateur iOS, sur macOS : `bazel test //shared/feature/login:login_native_test`. Le simulateur par défaut s'appelle `iPhone 17` ; en choisir un autre avec `--test_env=KOTLIN_NATIVE_TEST_DEVICE=<nom ou UDID>`.

## Règles Kotlin/Native

Aucune règle Bazel publiée ne construit Kotlin/Native : `bazel/kotlin_native` appelle le compilateur `konanc` de la distribution que `MODULE.bazel` télécharge.

- Le compilateur tourne sur un Mac Apple silicon seulement. Ailleurs, les cibles `_native` sont incompatibles et Bazel les saute.
- Les klibs des bibliothèques viennent de `kotlin_native.libraries`, dans `MODULE.bazel`, résolues avec leurs dépendances depuis les métadonnées Gradle qu'elles publient.
- Chaque klib est compilée pour les deux cibles, appareil et simulateur, quelle que soit la cible du build.
