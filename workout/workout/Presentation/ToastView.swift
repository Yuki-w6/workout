import SwiftUI

struct ToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.square")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.green)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.9))
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
        .accessibilityLabel(message)
    }
}

private struct ToastPresenter: ViewModifier {
    let message: String
    @Binding var isPresented: Bool
    let duration: TimeInterval

    @State private var dismissWorkItem: DispatchWorkItem?

    func body(content: Content) -> some View {
        ZStack {
            content
            if isPresented {
                ToastView(message: message)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        scheduleDismiss()
                    }
            }
        }
        .onChange(of: isPresented) { _, newValue in
            if newValue {
                scheduleDismiss()
            } else {
                dismissWorkItem?.cancel()
                dismissWorkItem = nil
            }
        }
        .onChange(of: message) { _, _ in
            if isPresented {
                scheduleDismiss()
            }
        }
    }

    private func scheduleDismiss() {
        dismissWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.2)) {
                isPresented = false
            }
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }
}

extension View {
    func toast(message: String, isPresented: Binding<Bool>, duration: TimeInterval = 1.6) -> some View {
        modifier(ToastPresenter(message: message, isPresented: isPresented, duration: duration))
    }
}
