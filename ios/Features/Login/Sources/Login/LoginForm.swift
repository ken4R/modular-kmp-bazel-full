import DesignSystem
import SharedKit
import SwiftUI

/// The login form. It only renders `state` and reports what the user does: no logic lives here.
struct LoginForm: View {

    let state: LoginUiState
    let onEmailChanged: (String) -> Void
    let onPasswordChanged: (String) -> Void
    let onSubmit: () -> Void
    let onForgotPassword: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Connexion")
                .font(.title.bold())

            Group {
                TextField("E-mail", text: Binding(get: { state.email }, set: onEmailChanged))
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)

                SecureField("Mot de passe", text: Binding(get: { state.password }, set: onPasswordChanged))
                    .textContentType(.password)
                    .submitLabel(.done)
                    .onSubmit(onSubmit)
            }
            .textFieldStyle(.roundedBorder)
            .disabled(state.isSubmitting)

            if let error = state.error {
                Text(error.message)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            PrimaryButton("Se connecter", isLoading: state.isSubmitting, action: onSubmit)
                .disabled(!state.canSubmit)

            Button("Mot de passe oublié ?", action: onForgotPassword)
                .disabled(state.isSubmitting)

            Text("Prototype : le mot de passe est « kotlin ».")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
    }
}

extension LoginError {

    /// Wording is a platform concern: the shared code only says which error happened.
    var message: LocalizedStringKey {
        // Swift sees the Kotlin enum as a class: the switch needs a default case.
        switch self {
        case .invalidEmail: return "Adresse e-mail invalide."
        case .invalidCredentials: return "E-mail ou mot de passe incorrect."
        default: return "Une erreur est survenue."
        }
    }
}

#Preview("Formulaire vide") {
    LoginForm(
        state: LoginUiState(email: "", password: "", isSubmitting: false, error: nil),
        onEmailChanged: { _ in },
        onPasswordChanged: { _ in },
        onSubmit: {},
        onForgotPassword: {}
    )
}

#Preview("Identifiants refusés") {
    LoginForm(
        state: LoginUiState(
            email: "ada@example.com",
            password: "secret",
            isSubmitting: false,
            error: .invalidCredentials
        ),
        onEmailChanged: { _ in },
        onPasswordChanged: { _ in },
        onSubmit: {},
        onForgotPassword: {}
    )
}
