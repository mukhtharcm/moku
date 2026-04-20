import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                WelcomePage(onNext: { withAnimation { currentPage = 1 } })
                    .tag(0)
                ImportPage(
                    onNext: { withAnimation { currentPage = 2 } },
                    onImport: {
                        withAnimation { currentPage = 2 }
                    }
                )
                    .tag(1)
                SyncPage(onFinish: { completeOnboarding() })
                    .tag(2)
            }

            // Page indicator
            HStack(spacing: 8) {
                if currentPage < 2 {
                    Button("Skip") { completeOnboarding() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                } else {
                    Spacer().frame(width: 50)
                }

                Spacer()

                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? Color.accentColor : Color.secondary.opacity(0.2))
                            .frame(width: i == currentPage ? 20 : 8, height: 8)
                            .animation(.easeOut(duration: 0.3), value: currentPage)
                    }
                }

                Spacer()
                Spacer().frame(width: 50)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(width: 600, height: 450)
    }

    private func completeOnboarding() {
        OnboardingManager.markCompleted()
        withAnimation(.easeInOut(duration: 0.4)) {
            isPresented = false
        }
    }
}

// MARK: - Welcome Page

private struct WelcomePage: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "bookmark.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
                .padding(.bottom, 24)

            Text("Welcome to Moku")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .padding(.bottom, 8)

            Text("Your cozy reading companion")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)

            Text("Import your EPUB books, track progress,\nand read distraction-free.")
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Spacer()

            Button(action: onNext) {
                Text("Get Started")
                    .frame(maxWidth: 240)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 48)
    }
}

// MARK: - Import Page

private struct ImportPage: View {
    let onNext: () -> Void
    let onImport: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "doc.badge.plus")
                .font(.system(size: 55))
                .foregroundStyle(.blue)
                .padding(.bottom, 24)

            Text("Import Your Books")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .padding(.bottom, 8)

            Text("Add EPUB files from your Mac.\nYour books stay local — fully offline.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            VStack(spacing: 10) {
                Button(action: onImport) {
                    Label("Import an EPUB", systemImage: "plus")
                        .frame(maxWidth: 240)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("I'll do this later") { onNext() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 48)
    }
}

// MARK: - Sync Page

private struct SyncPage: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 55))
                .foregroundStyle(.indigo)
                .padding(.bottom, 24)

            Text("Sync Across Devices")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .padding(.bottom, 8)

            Text("Moku works fully offline — no account needed.")
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.bottom, 6)

            Text("Want to sync books and progress across devices?\nConnect your own PocketBase server in Settings.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button(action: onFinish) {
                Label("Start Reading", systemImage: "book")
                    .frame(maxWidth: 240)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 48)
    }
}
