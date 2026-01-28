import SwiftUI

struct AuthView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var authMode: AuthMode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isBusiness = false
    @State private var showPassword = false
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var agreedToTerms = false
    @State private var showBiometricPrompt = false
    
    @FocusState private var focusedField: Field?
    
    enum AuthMode {
        case login, signup, forgotPassword
    }
    
    enum Field {
        case name, email, password
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        headerSection
                        
                        // Main Auth Form
                        authFormSection
                        
                        // Biometric Login (only on login screen)
                        if authMode == .login && authViewModel.biometricAvailable {
                            dividerWithText
                            biometricLoginButton
                        }
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 40)
                }
            }
            .navigationBarHidden(true)
            .overlay(alignment: .topLeading) {
                // Close button (only show if already logged in)
                if authViewModel.isLoggedIn {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(AppColors.textTertiary)
                            .padding(20)
                    }
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) {
                    if alertTitle.contains("Success") || alertTitle.contains("✅") {
                        handleSuccessfulAuth()
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .alert("Enable Biometric Login", isPresented: $showBiometricPrompt) {
                Button("Enable") {
                    enableBiometricLogin()
                }
                Button("Not Now", role: .cancel) {
                    // User declined
                }
            } message: {
                Text("Would you like to enable \(authViewModel.biometricTypeString) for quick sign in?")
            }
            .overlay {
                if isLoading {
                    loadingOverlay
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    var headerSection: some View {
        VStack(spacing: 16) {
            // App Logo/Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.primary, AppColors.primary.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: AppColors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
                
                Image(systemName: "building.2.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text(authMode == .login ? "Sign In" :
                     authMode == .signup ? "Create Account" :
                     "Reset Password")
                    .font(AppFonts.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(authMode == .login ? "Enter your credentials to continue" :
                     authMode == .signup ? "Join our community today" :
                     "We'll send you a reset link")
                    .font(AppFonts.callout)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
    
    // MARK: - Auth Form Section
    
    var authFormSection: some View {
        VStack(spacing: 20) {
            // Name field (signup only)
            if authMode == .signup {
                ModernTextField(
                    icon: "person.fill",
                    placeholder: "Full Name",
                    text: $name,
                    focusedField: $focusedField,
                    field: .name
                )
                .textContentType(.name)
                .submitLabel(.next)
                .onSubmit { focusedField = .email }
            }
            
            // Email field
            ModernTextField(
                icon: "envelope.fill",
                placeholder: "Email",
                text: $email,
                focusedField: $focusedField,
                field: .email
            )
            .textContentType(authMode == .signup ? .emailAddress : .username)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .submitLabel(authMode == .forgotPassword ? .send : .next)
            .onSubmit {
                if authMode == .forgotPassword {
                    handleAuth()
                } else {
                    focusedField = .password
                }
            }
            
            // Password field (not for forgot password)
            if authMode != .forgotPassword {
                ModernPasswordField(
                    placeholder: authMode == .signup ? "Create Password" : "Password",
                    text: $password,
                    showPassword: $showPassword,
                    focusedField: $focusedField,
                    field: .password
                )
                .textContentType(authMode == .signup ? .newPassword : .password)
                .submitLabel(.go)
                .onSubmit { handleAuth() }
                
                // Password strength indicator (signup only)
                if authMode == .signup && !password.isEmpty {
                    PasswordStrengthView(password: password)
                }
            }
            
            // Forgot password (login only)
            if authMode == .login {
                HStack {
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            authMode = .forgotPassword
                            focusedField = nil
                        }
                    }) {
                        Text("Forgot Password?")
                            .font(AppFonts.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
            
            // Business owner toggle (signup only)
            if authMode == .signup {
                HStack(alignment: .center, spacing: 12) {
                    Toggle("", isOn: $isBusiness)
                        .toggleStyle(CheckboxToggleStyle())
                        .frame(width: 24, height: 24)
                    
                    Text("I'm a business owner")
                        .font(AppFonts.callout)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
            
            // Terms agreement (signup only)
            if authMode == .signup {
                HStack(alignment: .center, spacing: 12) {
                    Toggle("", isOn: $agreedToTerms)
                        .toggleStyle(CheckboxToggleStyle())
                        .frame(width: 24, height: 24)
                    
                    Text("I agree to the ")
                        .font(AppFonts.callout)
                        .foregroundColor(AppColors.textSecondary)
                    +
                    Text("Terms of Service")
                        .font(AppFonts.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primary)
                    +
                    Text(" and ")
                        .font(AppFonts.callout)
                        .foregroundColor(AppColors.textSecondary)
                    +
                    Text("Privacy Policy")
                        .font(AppFonts.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primary)
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
            
            // Main Action Button
            Button(action: handleAuth) {
                HStack(spacing: 12) {
                    if !isLoading {
                        Image(systemName: authMode == .login ? "lock.fill" :
                              authMode == .signup ? "person.badge.plus.fill" :
                              "envelope.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    
                    Text(authMode == .login ? "Sign In" :
                         authMode == .signup ? "Create Account" :
                         "Send Reset Link")
                        .font(AppFonts.body)
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [AppColors.primary, AppColors.primary.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(AppRadius.md)
                .shadow(color: AppColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(isLoading || !isFormValid)
            .opacity(isFormValid ? 1.0 : 0.6)
            .padding(.top, 8)
            
            // Toggle auth mode
            HStack(spacing: 4) {
                Text(authMode == .login ? "Don't have an account?" :
                     authMode == .signup ? "Already have an account?" :
                     "Remember your password?")
                    .font(AppFonts.callout)
                    .foregroundColor(AppColors.textSecondary)
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if authMode == .login {
                            authMode = .signup
                        } else {
                            authMode = .login
                        }
                        focusedField = nil
                        clearForm()
                    }
                }) {
                    Text(authMode == .login ? "Sign Up" : "Sign In")
                        .font(AppFonts.callout)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primary)
                }
            }
            .padding(.top, 4)
        }
    }
    
    // MARK: - Divider
    
    var dividerWithText: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1)
            
            Text("OR")
                .font(AppFonts.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textTertiary)
            
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1)
        }
    }
    
    // MARK: - Biometric Login
    
    var biometricLoginButton: some View {
        Button(action: handleBiometricAuth) {
            VStack(spacing: 8) {
                Image(systemName: authViewModel.biometricIcon)
                    .font(.system(size: 40))
                    .foregroundColor(AppColors.primary)
                
                Text("Unlock with \(authViewModel.biometricTypeString)")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(AppColors.surface)
            .cornerRadius(AppRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(AppColors.border, lineWidth: 1.5)
            )
        }
        .padding(.top, 12)
    }
    
    // MARK: - Loading Overlay
    
    var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text(authMode == .login ? "Signing in..." :
                     authMode == .signup ? "Creating account..." :
                     "Sending reset link...")
                    .font(AppFonts.callout)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(AppColors.surface.opacity(0.95))
            .cornerRadius(AppRadius.lg)
        }
    }
    
    // MARK: - Helper Functions
    
    var isFormValid: Bool {
        switch authMode {
        case .login:
            return !email.isEmpty && !password.isEmpty
        case .signup:
            return !email.isEmpty && !password.isEmpty && !name.isEmpty && agreedToTerms
        case .forgotPassword:
            return !email.isEmpty
        }
    }
    
    func clearForm() {
        email = ""
        password = ""
        name = ""
        isBusiness = false
        agreedToTerms = false
    }
    
    func handleAuth() {
        focusedField = nil
        isLoading = true
        
        switch authMode {
        case .login:
            authViewModel.signIn(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password
            ) { success, message in
                handleAuthResponse(success: success, message: message)
                
                // Show biometric prompt after successful login
                if success && authViewModel.biometricAvailable {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showBiometricPrompt = true
                    }
                }
            }
            
        case .signup:
            authViewModel.signUp(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password,
                name: name.trimmingCharacters(in: .whitespaces),
                isBusiness: isBusiness,
                completion: { success, message in
                    handleAuthResponse(success: success, message: message)
                    
                    // Show biometric prompt after successful signup
                    if success && authViewModel.biometricAvailable {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showBiometricPrompt = true
                        }
                    }
                }
            )
            
        case .forgotPassword:
            authViewModel.resetPassword(
                email: email.trimmingCharacters(in: .whitespaces),
                completion: { success, message in
                    handleAuthResponse(success: success, message: message)
                }
            )
        }
    }
    
    func enableBiometricLogin() {
        // Credentials are already saved to keychain during sign-in/sign-up
        // This function is called when user explicitly enables biometric login from the prompt
        authViewModel.saveCredentialsToKeychain(email: email, password: password)
    }
    
    func handleBiometricAuth() {
        isLoading = true
        authViewModel.authenticateWithBiometrics { success, message in
            handleAuthResponse(success: success, message: message)
        }
    }
    
    func handleAuthResponse(success: Bool, message: String) {
        isLoading = false
        alertTitle = success ? "Success ✅" : "Error ❌"
        alertMessage = message
        showAlert = true
    }
    
    func handleSuccessfulAuth() {
        if authMode == .forgotPassword {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                authMode = .login
                clearForm()
            }
        } else {
            // Already logged in via AuthViewModel state change
            if authViewModel.isLoggedIn {
                dismiss()
            }
        }
    }
}

// MARK: - Modern Text Field

struct ModernTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var focusedField: FocusState<AuthView.Field?>.Binding
    let field: AuthView.Field
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(focusedField.wrappedValue == field ? AppColors.primary : AppColors.textTertiary)
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .font(AppFonts.body)
                .foregroundColor(AppColors.textPrimary)
                .focused(focusedField, equals: field)
        }
        .padding(16)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(
                    focusedField.wrappedValue == field ? AppColors.primary : AppColors.border,
                    lineWidth: focusedField.wrappedValue == field ? 2 : 1
                )
        )
    }
}

// MARK: - Modern Password Field

struct ModernPasswordField: View {
    let placeholder: String
    @Binding var text: String
    @Binding var showPassword: Bool
    var focusedField: FocusState<AuthView.Field?>.Binding
    let field: AuthView.Field
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(focusedField.wrappedValue == field ? AppColors.primary : AppColors.textTertiary)
                .frame(width: 20)
            
            Group {
                if showPassword {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .font(AppFonts.body)
            .foregroundColor(AppColors.textPrimary)
            .focused(focusedField, equals: field)
            
            Button(action: { showPassword.toggle() }) {
                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(16)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(
                    focusedField.wrappedValue == field ? AppColors.primary : AppColors.border,
                    lineWidth: focusedField.wrappedValue == field ? 2 : 1
                )
        )
    }
}

// MARK: - Password Strength View

struct PasswordStrengthView: View {
    let password: String
    
    var strength: PasswordStrength {
        let length = password.count
        let hasUppercase = password.contains(where: { $0.isUppercase })
        let hasLowercase = password.contains(where: { $0.isLowercase })
        let hasNumber = password.contains(where: { $0.isNumber })
        let hasSpecial = password.contains(where: { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) })
        
        var score = 0
        if length >= 6 { score += 1 }
        if length >= 8 { score += 1 }
        if hasUppercase && hasLowercase { score += 1 }
        if hasNumber { score += 1 }
        if hasSpecial { score += 1 }
        
        if score <= 2 { return .weak }
        if score <= 3 { return .medium }
        return .strong
    }
    
    enum PasswordStrength {
        case weak, medium, strong
        
        var color: Color {
            switch self {
            case .weak: return AppColors.error
            case .medium: return AppColors.warning
            case .strong: return AppColors.success
            }
        }
        
        var text: String {
            switch self {
            case .weak: return "Weak"
            case .medium: return "Medium"
            case .strong: return "Strong"
            }
        }
        
        var progress: CGFloat {
            switch self {
            case .weak: return 0.33
            case .medium: return 0.66
            case .strong: return 1.0
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Password strength:")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
                
                Text(strength.text)
                    .font(AppFonts.caption)
                    .fontWeight(.bold)
                    .foregroundColor(strength.color)
                
                Spacer()
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(AppColors.border)
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(strength.color)
                        .frame(width: geometry.size.width * strength.progress, height: 4)
                        .cornerRadius(2)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: strength.progress)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Checkbox Toggle Style

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundColor(configuration.isOn ? AppColors.primary : AppColors.textTertiary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
