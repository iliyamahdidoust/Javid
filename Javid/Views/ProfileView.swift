import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var businessViewModel: BusinessViewModel
    @State private var showingAddBusiness = false
    @State private var showingLoginSheet = false
    
    var userBusinesses: [Business] {
        businessViewModel.getUserBusinesses()
    }
    
    var isBusinessOwner: Bool {
        authViewModel.userProfile?.isBusinessOwner ?? false
    }
    
    var body: some View {
        NavigationView {
            if authViewModel.isLoggedIn {
                // Logged In View
                List {
                    Section(header: Text("Account")) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(authViewModel.currentUser?.displayName ?? "User")
                                    .font(.headline)
                                Text(authViewModel.currentUser?.email ?? "")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: isBusinessOwner ? "briefcase.fill" : "person.fill")
                                        .font(.caption)
                                    Text(isBusinessOwner ? "Business Owner" : "Regular User")
                                        .font(.caption)
                                }
                                .foregroundColor(isBusinessOwner ? .blue : .gray)
                                .padding(.top, 4)
                            }
                            .padding(.leading, 8)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    if isBusinessOwner {
                        Section(header: Text("My Businesses")) {
                            if userBusinesses.isEmpty {
                                Text("You haven't added any businesses yet")
                                    .foregroundColor(.gray)
                                    .italic()
                            } else {
                                ForEach(userBusinesses) { business in
                                    NavigationLink(destination: BusinessDetailView(business: business)) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(business.name)
                                                .font(.headline)
                                            Text(business.category)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            }
                            
                            Button(action: {
                                showingAddBusiness = true
                            }) {
                                Label("Add New Business", systemImage: "plus.circle.fill")
                            }
                        }
                    } else {
                        Section(header: Text("Business Owner Features")) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Want to add your business?")
                                    .font(.headline)
                                Text("You need a Business Owner account to add businesses. Contact support to upgrade your account.")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    
                    Section {
                        Button(action: {
                            authViewModel.signOut()
                        }) {
                            HStack {
                                Spacer()
                                Text("Logout")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    }
                }
                .navigationTitle("Profile")
                .sheet(isPresented: $showingAddBusiness) {
                    AddBusinessView(businessViewModel: businessViewModel)
                }
            } else {
                // Not Logged In View
                VStack(spacing: 30) {
                    Spacer()
                    
                    Image(systemName: "person.circle")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 12) {
                        Text("Sign in to access your profile")
                            .font(.title2)
                            .bold()
                        
                        Text("Create an account to add businesses, write reviews, and save your favorites")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    Button(action: {
                        showingLoginSheet = true
                    }) {
                        Text("Sign In / Sign Up")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: 250)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    
                    Spacer()
                }
                .navigationTitle("Profile")
                .sheet(isPresented: $showingLoginSheet) {
                    AuthView(authViewModel: authViewModel)
                }
            }
        }
    }
}
