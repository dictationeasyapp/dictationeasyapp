import SwiftUI

struct SubscriptionView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGray6) // Light background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Title
                        Text("Go Premium 升級高級版")
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.top, 20)
                        
                        // Card-like container for content
                        VStack(spacing: 20) {
                            // Subtitle
                            Text("Unlock Premium Features 解鎖高級功能")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            // Features Header
                            Text("Premium Benefits 高級優勢")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            // List of premium features
                            VStack(alignment: .leading, spacing: 12) {
                                FeatureRow(text: "Full access to Teacher Mode 完全訪問教師模式")
                                FeatureRow(text: "View and edit past dictations 查看和編輯過去文章")
                                FeatureRow(text: "Use the Random button 使用隨機按鈕")
                                FeatureRow(text: "Include punctuations in playback 在播放中包含標點")
                                FeatureRow(text: "Ad-free experience 無廣告體驗")
                            }
                            .padding(.horizontal)
                            
                            // Subscription Options
                            if subscriptionManager.availablePackages.isEmpty {
                                Text("No subscription options available. Please try again later. 目前沒有可用的訂閱選項。請稍後再試。")
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                            } else {
                                ForEach(subscriptionManager.availablePackages, id: \.identifier) { package in
                                    Button(action: {
                                        Task {
                                            await subscriptionManager.purchasePackage(package)
                                        }
                                    }) {
                                        Text("Subscribe \(package.storeProduct.localizedTitle) for \(package.localizedPriceString)")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.blue)
                                            .cornerRadius(12)
                                            .shadow(radius: 3)
                                    }
                                    .padding(.horizontal)
                                    .disabled(subscriptionManager.isLoading)
                                }
                            }
                            
                            // Restore Purchases Button
                            Button(action: {
                                Task {
                                    await subscriptionManager.restorePurchases()
                                }
                            }) {
                                Text("Restore Purchases 恢復購買")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.blue, lineWidth: 1)
                                    )
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                            .disabled(subscriptionManager.isLoading)
                            
                            // Error Message
                            if let error = subscriptionManager.errorMessage {
                                Text(error)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(15)
                        .shadow(radius: 5)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarItems(leading: Button("Cancel 取消") { dismiss() })
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// Custom view for feature rows with icons
struct FeatureRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.blue)
                .font(.system(size: 16))
            Text(text)
                .lineLimit(nil) // Allow text to wrap
                .foregroundColor(.black)
        }
    }
}

#Preview {
    SubscriptionView()
        .environmentObject(SubscriptionManager.shared)
}
