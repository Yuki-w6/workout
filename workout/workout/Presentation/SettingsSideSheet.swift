import SwiftUI

struct SettingsSideSheet: View {
    @Binding var isPresented: Bool
    private let actionLabelColor: Color = .secondary
    @Environment(\.openURL) private var openURL

    var body: some View {
        GeometryReader { proxy in
            let width = min(320, proxy.size.width * 0.82)

            ZStack(alignment: .leading) {
                if isPresented {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isPresented = false
                            }
                        }
                }

                VStack(alignment: .leading, spacing: 28) {
                    Text("筋トレログ")
                        .font(.title2.weight(.bold))
                        .padding(.top, 28)

                    Divider()

                    settingsButton(
                        title: "プライバシーポリシー",
                        systemImage: "hand.raised",
                        urlString: "https://celestial-estimate-0db.notion.site/2e5540c9e672805d8c8ed7f60f9c328f"
                    )
                    settingsButton(
                        title: "よくある質問",
                        systemImage: "questionmark.circle",
                        urlString: "https://celestial-estimate-0db.notion.site/2e5540c9e67280dcbc80f99d961593db"
                    )
                    settingsButton(title: "データの削除", systemImage: "trash")

                    Spacer()
                }
                .padding(.horizontal, 20)
                .frame(width: width, height: proxy.size.height, alignment: .topLeading)
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.2), radius: 12, x: 6, y: 0)
                .offset(x: isPresented ? 0 : -width - 12)
                .animation(.easeInOut(duration: 0.25), value: isPresented)
                .gesture(
                    DragGesture().onEnded { value in
                        guard isPresented, value.translation.width < -50 else {
                            return
                        }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isPresented = false
                        }
                    }
                )
            }
        }
        .allowsHitTesting(isPresented)
    }

    private func settingsButton(title: String, systemImage: String, urlString: String? = nil) -> some View {
        Button {
            guard let urlString, let url = URL(string: urlString) else {
                return
            }
            openURL(url)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .frame(width: 22)
                Text(title)
                    .font(.headline)
            }
            .foregroundStyle(actionLabelColor)
        }
    }
}
