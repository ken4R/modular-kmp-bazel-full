# modular-kmp-bazel-full

Application mobile iOS et Android. La logique est écrite une seule fois en Kotlin Multiplatform. L'interface est native : Jetpack Compose sur Android, SwiftUI sur iOS.

Ce dépôt est le prototype de la solution C : Bazel construit tout, le code partagé, l'application Android et l'application iOS. Il n'y a pas de Gradle. Le prototype A (`ken4R/modular-kmp-bazel`) porte la même application avec Gradle pour le code partagé et Android.

## Carte du dépôt

| Zone | Contenu | À lire avant d'y toucher |
|---|---|---|
| `shared/` | Logique commune, Kotlin Multiplatform | `shared/AGENTS.md` |
| `android/` | Application et écrans Compose | `android/AGENTS.md` |
| `ios/` | Application et vues SwiftUI, un paquet Swift par module | `ios/AGENTS.md` |
| `bazel/` | Règles Kotlin/Native maison, toolchain Kotlin, Robolectric | ce fichier, puis les commentaires des `.bzl` |
| `tools/` | Scripts du dépôt | |
| `MODULE.bazel` | Toutes les versions : règles Bazel, Kotlin, bibliothèques | ce fichier |

Les deux mondes se rejoignent dans le framework `Shared`. Bazel le construit depuis `shared/umbrella` et l'application iOS le lie directement : aucun fichier n'est copié pour le build Bazel. Seuls les paquets Swift, ouverts seuls dans Xcode, lisent une copie, `ios/SharedKit/Frameworks/Shared.xcframework`, que `tools/shared/sync` construit.

## Commandes

Sur Linux ou macOS :

- `bazel test //shared/... //android/...` : tests du code partagé sur JVM, tests d'écran Compose, APK, et règles de dépendance.
- `bazel test //shared/feature/login:login_test` : les tests JVM d'un seul module.
- `bazel build //android/app` : l'application Android, dans `bazel-bin/android/app/app.apk`.

Sur macOS seulement :

- `bazel test //shared/...` : en plus, les tests Kotlin/Native dans un simulateur iOS.
- `bazel test //ios/...` : construit le framework `Shared` et l'application iOS, lance ses tests et vérifie les `Package.swift`.
- `bazel run //ios:xcodeproj` : génère `ios/Modular.xcodeproj`.
- `bazel run //ios/Features/Login:package_swift` : régénère le `Package.swift` d'un module.
- `tools/shared/sync` : construit `Shared.xcframework` pour les paquets Swift. À relancer après tout changement sous `shared/`, avant d'ouvrir un paquet Swift.

Outils attendus : Bazelisk et le SDK Android (`ANDROID_HOME`, avec la plateforme `android-37`) partout, Xcode 26.4 et un Mac Apple silicon pour iOS. Bazelisk lit la version de Bazel dans `.bazelversion`. Bazel télécharge le reste : le JDK, le compilateur Kotlin, le compilateur Kotlin/Native et les bibliothèques.

## Types de modules

Le `BUILD.bazel` d'un module appelle une seule macro. La macro configure tout : cibles, SDK, tests, dépendances communes, visibilité.

| Dossier | Déclaration | Rôle |
|---|---|---|
| `shared/core/<nom>` | `kmp_core(...)` | Brique commune : session, réseau, modèle |
| `shared/feature/<nom>` | `kmp_feature(...)` | Logique d'une feature : ViewModel, état, événements |
| `shared/umbrella` | `kmp_umbrella(...)` | Produit le framework iOS `Shared` et assemble les dépendances |
| `android/core/<nom>` | `android_core(...)` | Composants Compose communs |
| `android/feature/<nom>` | `android_feature(...)` | Écrans Compose d'une feature |
| `android/app` | `android_app(...)` | Application Android, navigation |
| `ios/Core/<Nom>`, `ios/Features/<Nom>`, `ios/SharedKit` | `ios_module(...)` | Module Swift, aussi paquet Swift |
| `ios/App` | `ios_application(...)` | Application iOS, navigation |

Les macros sont dans `shared/kmp_module.bzl`, `android/android_module.bzl` et `ios/ios_module.bzl`.

## Règles

1. Aucune logique métier dans `android/` ni dans `ios/`. Un écran affiche un état et transmet des actions.
2. Une feature ne dépend jamais d'une autre feature. Ce qui est commun descend dans un module `core`.
3. Les dépendances entre modules suivent le tableau ci-dessous. Le build les refuse sinon, dans les trois zones : les macros vérifient les `deps` et la visibilité Bazel fait le reste.
4. Les versions vivent dans `MODULE.bazel`, jamais dans un module. Les niveaux de SDK Android sont dans `android/android_module.bzl`, la version minimale d'iOS dans `ios/ios_module.bzl`.
5. Les règles Bazel tierces ne sont chargées que par les macros et par `bazel/`. Le `BUILD.bazel` d'un module ne charge que sa macro.
6. Ne jamais modifier à la main : les `Package.swift` des modules iOS, `ios/SharedKit/Frameworks/`, les projets Xcode.
7. Le code et ses commentaires sont en anglais. La documentation et les textes affichés à l'utilisateur sont en français.

| Module | Peut dépendre de |
|---|---|
| `shared/core/*` | `shared/core/*` |
| `shared/feature/<nom>` | `shared/core/*` |
| `shared/umbrella` | `shared/core/*`, `shared/feature/*` |
| `android/core/*` | `android/core/*`, `shared/core/*` |
| `android/feature/<nom>` | `shared/feature/<nom>`, `shared/core/*`, `android/core/*` |
| `android/app` | tout |
| `ios/Core/*`, `ios/SharedKit` | `ios/Core/*`, `ios/SharedKit` |
| `ios/Features/<Nom>` | `ios/Core/*`, `ios/SharedKit` |
| `ios/App` | tout |

## Ajouter une feature

La feature `login` sert de modèle : copier sa structure. Bazel trouve seul un nouveau dossier qui a un `BUILD.bazel`.

1. Logique : créer `shared/feature/<nom>/BUILD.bazel` avec `kmp_feature(name = "<nom>", deps = [...])`, écrire le ViewModel dans `src/commonMain` et ses tests dans `src/commonTest`.
2. Pont vers Swift : dans `shared/umbrella/BUILD.bazel`, ajouter le module à `export_to_swift`. Dans `SharedGraph`, ajouter la fonction qui crée le ViewModel.
3. Android : créer `android/feature/<nom>/BUILD.bazel` avec `android_feature`, l'ajouter aux `deps` de `android/app`, brancher l'écran dans `AppRoot`.
4. iOS : créer `ios/Features/<Nom>/BUILD.bazel` avec `ios_module`, lancer `bazel run //ios/Features/<Nom>:package_swift`, ajouter le module aux dépendances de `ios/App`, ses tests à `ios/BUILD.bazel`, et brancher la vue dans `RootView`.

## Ajouter une bibliothèque ou changer de version

- Une bibliothèque Android ou JVM s'ajoute à `maven.install` dans `MODULE.bazel`.
- Une bibliothèque Kotlin Multiplatform utilisée par le code partagé s'ajoute deux fois, à la même version : à `maven.install` pour la JVM, et à `kotlin_native.libraries` pour iOS. Les macros de `shared/kmp_module.bzl` nomment ensuite `@maven//:…` et `@klibs//:…`.
- Kotlin a une seule version, celle de `rules_kotlin`. La changer veut dire changer ensemble `rules_kotlin`, `kotlin_native.toolchain` (version, sha256 de la distribution, et les archives LLVM et libffi que liste son `konan/konan.properties`) et le plugin du compilateur Compose.

## Terminé veut dire

- Les contrôles de la zone touchée passent : `bazel test //shared/... //android/...` pour `shared/` et `android/`, `bazel test //shared/... //ios/...` sur macOS pour `ios/` et pour tout changement de `shared/` visible depuis Swift.
- Les fichiers générés sont à jour.
- Aucune règle de dépendance n'est enfreinte.
- Le comportement ajouté a un test, dans la couche où il vit.

## Ce qu'un agent peut vérifier

| Contrôle | Linux | macOS |
|---|---|---|
| Tests JVM du code partagé, règles de dépendance | Oui | Oui |
| Build et tests Android | Oui, avec le SDK Android | Oui |
| Framework `Shared` et tests Kotlin/Native | Non | Oui, sur Apple silicon |
| Build et tests iOS avec Bazel, paquets Swift | Non | Oui, sur Apple silicon |

Sur Linux, `bazel test //shared/... //android/...` saute les cibles Kotlin/Native au lieu d'échouer. Un agent sur Linux ne peut donc pas valider un changement iOS. Il s'appuie sur la CI macOS de la pull request et le dit dans sa description : ce qui a été vérifié, et ce qui ne l'a pas été.
