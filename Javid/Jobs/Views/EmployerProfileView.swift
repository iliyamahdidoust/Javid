import SwiftUI

struct EmployerProfileView: View {
    @StateObject private var viewModel = EmployerProfileViewModel()
    @State private var showingEditProfile = false
    @State private var showingVerificationSubmit = false
    
    var body: some View {
        ScrollView {
            if let profile = viewModel.employerProfile {
                VStack(spacing: 24) {
                    // Header with Logo
                    VStack(spacing: 16) {
                        if let logoURL = profile.logoURL {
                            AsyncImage(url: URL(string: logoURL)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Image(systemName: "building.2.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 100, height: 100)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        } else {
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                                .frame(width: 100, height: 100)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                        
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Text(profile.companyName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                if profile.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.blue)
                                        .font(.title3)
                                }
                            }
                            
                            Text(profile.industry)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    
                    // Verification Status Card
                    VerificationStatusCard(
                        status: profile.verificationStatus,
                        isVerified: profile.isVerified,
                        onSubmitVerification: {
                            showingVerificationSubmit = true
                        }
                    )
                    
                    // Company Information
                    VStack(alignment: .leading, spacing: 16) {
                        EmployerSectionHeader(title: "Company Information")
                        
                        CompanyInfoRow(icon: "building.2.fill", title: "Company Size", value: profile.companySize.rawValue)
                        CompanyInfoRow(icon: "mappin.circle.fill", title: "Location", value: profile.location)
                        CompanyInfoRow(icon: "globe", title: "Website", value: profile.website)
                        
                        if !profile.description.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    Text("About")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                
                                Text(profile.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Contact Information
                    VStack(alignment: .leading, spacing: 16) {
                        EmployerSectionHeader(title: "Contact Information")
                        
                        CompanyInfoRow(icon: "envelope.fill", title: "Email", value: profile.contactEmail)
                        CompanyInfoRow(icon: "phone.fill", title: "Phone", value: profile.contactPhone)
                    }
                    .padding(.horizontal)
                    
                    // Edit Button
                    Button(action: { showingEditProfile = true }) {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Edit Profile")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // No profile - create one
                CreateEmployerProfilePrompt(onCreate: { showingEditProfile = true })
            }
        }
        .navigationTitle("Employer Profile")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingEditProfile) {
            EditEmployerProfileView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingVerificationSubmit) {
            VerificationSubmitView(viewModel: viewModel)
        }
    }
}

struct VerificationStatusCard: View {
    let status: VerificationStatus
    let isVerified: Bool
    let onSubmitVerification: () -> Void
    
    var backgroundColor: Color {
        switch status {
        case .notSubmitted: return .orange.opacity(0.1)
        case .pending: return .blue.opacity(0.1)
        case .approved: return .green.opacity(0.1)
        case .rejected: return .red.opacity(0.1)
        }
    }
    
    var foregroundColor: Color {
        switch status {
        case .notSubmitted: return .orange
        case .pending: return .blue
        case .approved: return .green
        case .rejected: return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: status.icon)
                    .font(.title2)
                    .foregroundColor(foregroundColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Verification Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(status.rawValue)
                        .font(.headline)
                        .foregroundColor(foregroundColor)
                }
                
                Spacer()
            }
            
            switch status {
            case .notSubmitted:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Get verified to build trust with job seekers")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: onSubmitVerification) {
                        HStack {
                            Image(systemName: "arrow.up.doc.fill")
                            Text("Submit Verification")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                
            case .pending:
                VStack(alignment: .leading, spacing: 8) {
                    Text("We're reviewing your verification documents. This usually takes 2-3 business days.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.blue)
                        Text("Under Review")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.vertical, 8)
                }
                
            case .approved:
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Your employer account is verified!")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                
            case .rejected:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your verification was not approved. Please review the feedback and resubmit.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: onSubmitVerification) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Resubmit Verification")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct EmployerSectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
    }
}

struct CompanyInfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct CreateEmployerProfilePrompt: View {
    let onCreate: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("Create Employer Profile")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Post jobs and find great candidates")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Button(action: onCreate) {
                Text("Get Started")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
