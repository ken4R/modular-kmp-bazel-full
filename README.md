# modular-kmp-bazel-full

Projet mobile modulaire, iOS et Android : la logique est écrite une seule fois en Kotlin Multiplatform, l'interface reste native sur chaque plateforme (SwiftUI et Jetpack Compose).

Ce dépôt porte le prototype de la solution C, dite tout Bazel : Bazel construit le code partagé, l'application Android et l'application iOS, sans Gradle. C'est une expérience bornée dans le temps, pour comparer avec la solution A (`ken4R/modular-kmp-bazel`, Gradle et Bazel) et la solution B (`ken4R/modular-kmp-bazel-both`).

## Ce que le prototype contient

Une feature de référence, `login`, traverse toutes les couches. Ses sources sont celles du prototype A : seuls les fichiers de build changent.

| Couche | Emplacement | Contenu |
|---|---|---|
| Logique partagée | `shared/feature/login` | `LoginViewModel`, son état, ses événements, ses tests |
| Brique commune | `shared/core/session` | Session de l'utilisateur, derrière une interface |
| Pont vers iOS | `shared/umbrella` | Framework `Shared`, lu par Swift à travers son en-tête Objective-C |
| Android | `android/feature/login`, `android/app` | Écran Compose, test d'écran, application |
| iOS | `ios/Features/Login`, `ios/App` | Vue SwiftUI, tests, application |
| Règles maison | `bazel/kotlin_native` | Compilation Kotlin/Native : klibs, framework, tests dans un simulateur |

Chaque module iOS est construit par Bazel et reste un paquet Swift : son `Package.swift` est généré depuis son `BUILD.bazel`.

## Démarrer

Outils : [Bazelisk](https://github.com/bazelbuild/bazelisk) et le SDK Android avec la plateforme `android-37`, et pour iOS un Mac Apple silicon avec Xcode 26.4. Bazel télécharge le JDK, Kotlin, le compilateur Kotlin/Native et les bibliothèques.

Code partagé et Android, sur Linux ou macOS :

```sh
bazel test //shared/... //android/...   # tests, règles de dépendance, APK
bazel build //android/app               # bazel-bin/android/app/app.apk
```

iOS, sur macOS :

```sh
bazel test //shared/... //ios/...   # framework Shared, tests Kotlin/Native et iOS
bazel run //ios:xcodeproj           # génère ios/Modular.xcodeproj
tools/shared/sync                   # Shared.xcframework, pour ouvrir un module comme paquet Swift
```

Dans l'application, n'importe quelle adresse e-mail se connecte avec le mot de passe `kotlin`.

## Organisation

```
shared/        logique commune, Kotlin Multiplatform
android/       application et écrans Compose
ios/           application et vues SwiftUI, un paquet Swift par module
bazel/         règles Kotlin/Native maison, toolchain Kotlin, Robolectric
tools/         scripts du dépôt
MODULE.bazel   toutes les versions
```

Les règles du dépôt, les types de modules et la marche à suivre pour ajouter une feature sont dans [AGENTS.md](AGENTS.md). Ce fichier sert aux développeurs comme aux agents de code. Chaque zone a le sien : [shared](shared/AGENTS.md), [android](android/AGENTS.md), [ios](ios/AGENTS.md).

## Intégration continue

La CI GitHub Actions lance sur Linux les tests JVM du code partagé, les tests d'écran Android et le build de l'APK. Sur macOS, elle lance les tests Kotlin/Native dans un simulateur iOS, le build et les tests iOS avec Bazel, et le build d'un module comme paquet Swift. Voir [.github/workflows/ci.yml](.github/workflows/ci.yml).

## Valeurs provisoires

L'identifiant d'application `com.example.modular`, le SDK Android minimum 26 et iOS 17 sont des valeurs de prototype, à remplacer quand elles seront décidées.
