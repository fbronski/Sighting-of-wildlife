import SwiftUI

struct SplashRootView: View {
    let viewModel: RootViewModel
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        showSplash = false
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.02)))
            } else {
                RootView(viewModel: viewModel)
                    .transition(.opacity)
            }
        }
        .background(Color.black)
    }
}

private struct SplashView: View {
    let onFinished: () -> Void
    @State private var progress = 0.0
    @State private var imageScale = 1.05
    @State private var contentOpacity = 0.0

    var body: some View {
        ZStack {
            Image("SplashWildMonitoring")
                .resizable()
                .scaledToFill()
                .scaleEffect(imageScale)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    .black.opacity(0.12),
                    .black.opacity(0.10),
                    .black.opacity(0.64)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                Spacer()

                VStack(spacing: 8) {
                    Text("WildLife Notifications")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.45), radius: 12, y: 4)

                    Text("Wildmonitoring")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))
                        .textCase(.uppercase)
                }
                .padding(.horizontal, 28)

                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(Color(red: 0.43, green: 0.82, blue: 0.58))
                    .frame(maxWidth: 220)
                    .padding(.top, 10)
                    .accessibilityLabel("Loading")

                Spacer()
                    .frame(height: 58)
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.7)) {
                imageScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.35)) {
                contentOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 1.35)) {
                progress = 1.0
            }

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_650_000_000)
                onFinished()
            }
        }
    }
}

#Preview {
    SplashView {}
}
