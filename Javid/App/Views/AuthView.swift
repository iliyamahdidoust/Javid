import SwiftUI

struct AuthView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var isLogin = true
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isBusiness = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var isSuccess = false
    @State private var showingForgotPassword = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Logo/Title
                    VStack(spacing: 8) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        Text("Iranian Businesses")
                            .font(.title)
                            .bold()
                        Text(isLogin ? "Welcome Back" : "Create Account")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 20)
                    
                    // Form
                    VStack(spacing: 16) {
                        if !isLogin {
                            TextField("Full Name", text: $name)
                                .textFieldStyle(RoundedTextFieldStyle())
                                .autocapitalization(.words)
                        }
                        
                        TextField("Email", text: $email)
                            .textFieldStyle(RoundedTextFieldStyle())
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                        
                        if !showingForgotPassword {
                            SecureField("Password", text: $password)
                                .textFieldStyle(RoundedTextFieldStyle())
                        }
                        
                        if !isLogin {
                            Toggle(isOn: $isBusiness) {
                                Text("I'm a business owner")
                                    .font(.subheadline)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Forgot Password Link (only visible in login mode)
                    if isLogin && !showingForgotPassword {
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation {
                                    showingForgotPassword = true
                                }
                            }) {
                                Text("Forgot Password?")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, -8)
                    }
                    
                    // Back to Login (when in forgot password mode)
                    if showingForgotPassword {
                        Button(action: {
                            withAnimation {
                                showingForgotPassword = false
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.left")
                                Text("Back to Login")
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        .padding(.top, -8)
                    }
                    
                    // Main Button
                    Button(action: handleAuth) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text(showingForgotPassword ? "Send Reset Email" : (isLogin ? "Login" : "Sign Up"))
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background(Color.blue)
                    .cornerRadius(12)
                    .disabled(isLoading)
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // Toggle Login/Signup (hidden in forgot password mode)
                    if !showingForgotPassword {
                        Button(action: {
                            isLogin.toggle()
                            // Clear fields when switching
                            email = ""
                            password = ""
                            name = ""
                        }) {
                            HStack(spacing: 4) {
                                Text(isLogin ? "Don't have an account?" : "Already have an account?")
                                    .foregroundColor(.gray)
                                Text(isLogin ? "Sign Up" : "Login")
                                    .foregroundColor(.blue)
                                    .bold()
                            }
                        }
                        .disabled(isLoading)
                        .padding(.top, 10)
                    }
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .alert(isSuccess ? "Success ✅" : "Error ❌", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {
                if isSuccess && showingForgotPassword {
                    // Reset to login after successful password reset
                    withAnimation {
                        showingForgotPassword = false
                        email = ""
                    }
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    func handleAuth() {
        // Reset success state
        isSuccess = false
        
        // Handle Forgot Password
        if showingForgotPassword {
            handleForgotPassword()
            return
        }
        
        // Validation
        if email.isEmpty {
            alertMessage = "❌ Please enter your email address"
            showingAlert = true
            return
        }
        
        if password.isEmpty {
            alertMessage = "❌ Please enter your password"
            showingAlert = true
            return
        }
        
        if !isLogin && name.isEmpty {
            alertMessage = "❌ Please enter your full name"
            showingAlert = true
            return
        }
        
        // Check email format
        if !email.contains("@") {
            alertMessage = "❌ Email must contain @"
            showingAlert = true
            return
        }
        
        if !email.contains(".") {
            alertMessage = "❌ Email must contain a domain (e.g., .com)"
            showingAlert = true
            return
        }
        
        // Check password length
        if password.count < 6 {
            alertMessage = "❌ Password must be at least 6 characters long"
            showingAlert = true
            return
        }
        
        isLoading = true
        
        if isLogin {
            // Sign In
            authViewModel.signIn(email: email.trimmingCharacters(in: .whitespaces),
                               password: password) { success, message in
                isLoading = false
                isSuccess = success
                alertMessage = message
                showingAlert = true
            }
        } else {
            // Sign Up
            authViewModel.signUp(email: email.trimmingCharacters(in: .whitespaces),
                               password: password,
                               name: name.trimmingCharacters(in: .whitespaces),
                               isBusiness: isBusiness) { success, message in
                isLoading = false
                isSuccess = success
                alertMessage = message
                showingAlert = true
            }
        }
    }
    
    func handleForgotPassword() {
        isLoading = true
        
        authViewModel.resetPassword(email: email.trimmingCharacters(in: .whitespaces)) { success, message in
            isLoading = false
            isSuccess = success
            alertMessage = message
            showingAlert = true
        }
    }
}

struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
    }
}
