import SwiftUI

struct SubscriptionView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Unlock Premium Features 解鎖高級功能")
                    .font(.title)
                    .padding()
                // List of premium features
                VStack(alignment: .leading, spacing: 10) {
                    Text("• Full access to Teacher Mode 完全訪問教師模式")
                    Text("• View and edit past dictations 查看和編輯過去文章")
                    Text("• Use the Random button 使用隨機按鈕")
                    Text("• Include punctuations in playback 在播放中包含標點")
                    Text("• Ad-free experience 無廣告體驗")
                }
                .padding(.horizontal)
                // Subscription Options
                if subscriptionManager.availablePackages.isEmpty {
                    Text("No subscription options available. Please try again later. 目前沒有可用的訂閱選項。請稍後再試。")
                        .foregroundColor(.red)
                        .padding(.horizontal)
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
                                .cornerRadius(10)
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
                }
                .padding()
                .disabled(subscriptionManager.isLoading)
                if let error = subscriptionManager.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Spacer()
            }
            .navigationTitle("Go Premium 升級高級版")
            .navigationBarItems(leading: Button("Cancel 取消") { dismiss() })
        }
    }
}

#Preview {
    SubscriptionView()
        .environmentObject(SubscriptionManager.shared)
}
