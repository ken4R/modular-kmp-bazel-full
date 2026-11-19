# android/ : application et écrans Compose

Interface Android en Jetpack Compose, construite par Bazel avec rules_kotlin et rules_android. Aucune logique métier ici : elle est dans `shared/`. Les règles communes du dépôt sont dans `AGENTS.md`, à la racine.

## Modules

- `app` : assemble les features et possède la navigation (`AppRoot`). Macro `android_app`.
- `core/<nom>` : composants Compose communs, comme `designsystem`. Macro `android_core`.
- `feature/<nom>` : écrans d'une feature. Macro `android_feature`.

Un module garde la disposition d'un module Gradle :

```
BUILD.bazel                     un appel de macro
src/main/kotlin/**/*.kt         code Compose
src/main/res/**                 facultatif : ressources Android
src/main/AndroidManifest.xml    l'application seulement : celui des bibliothèques est généré
src/test/kotlin/**/*.kt         facultatif : tests d'écran
```

```starlark
load("//android:android_module.bzl", "android_feature")

android_feature(
    name = "login",
    deps = [
        "//android/core/designsystem",
        "//shared/feature/login",
    ],
)
```

- Le paquet du code et de `R` vient du dossier : `android/feature/login` est `com.example.modular.feature.login`.
- Compose, Material 3, Lifecycle et les coroutines sont fournis par la macro : `deps` ne liste que des modules du dépôt.
- Une feature n'est visible que de `android/app`, et ne voit que la feature partagée du même nom.

## Écrire un écran

Le modèle est `feature/login`.

- `XxxRoute(viewModel, on…)` relie le ViewModel partagé à l'écran. Il collecte l'état avec `collectAsStateWithLifecycle(context = Dispatchers.Main.immediate)`, pour qu'un champ de texte ne soit jamais en retard d'une frappe, et transmet les événements dans un `LaunchedEffect`.
- `XxxScreen(state, on…)` est un composable sans état, avec un `@Preview`. Il affiche l'état et remonte les actions.
- Les textes sont dans le `src/main/res/values/strings.xml` du module.
- L'application crée le ViewModel : `viewModel { graph.loginViewModel() }`.

## Tests

- Tests d'écran sur JVM, avec Robolectric et `createComposeRule()`, dans `src/test`. Voir `LoginScreenTest`.
- `bazel test //android/feature/login:login_test`.
- Un fichier de test contient une classe du même nom, dans le paquet de son dossier. La macro lance toutes les classes dont le nom finit par `Test`, dans une seule cible.
- Robolectric tourne hors ligne, sur le jar Android de targetSdk que déclare `MODULE.bazel`. Changer targetSdk veut dire changer ce jar.

## Application

- `bazel build //android/app`, puis `adb install bazel-bin/android/app/app.apk`.
- L'identifiant d'application est dans `android/app/BUILD.bazel`, minSdk et targetSdk dans `android/android_module.bzl`. compileSdk est la plateforme la plus récente installée dans `ANDROID_HOME`.
- Le prototype ne lance pas Android Lint : rules_android ne le fournit pas, il faudrait ajouter une règle tierce.
