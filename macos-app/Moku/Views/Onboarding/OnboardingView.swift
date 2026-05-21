import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentPage = 0
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Warm background
            (colorScheme == .dark ? MokuTheme.nightSurface : MokuTheme.warmCream)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Content pages
                TabView(selection: $currentPage) {
                    WelcomePage { withAnimation(.spring(duration: 0.5)) { currentPage = 1 } }
                        .tag(0)
                    ImportPage(
                        onNext: { withAnimation(.spring(duration: 0.5)) { currentPage = 2 } },
                        onImport: { withAnimation(.spring(duration: 0.5)) { currentPage = 2 } }
                    )
                    .tag(1)
                    SyncPage { completeOnboarding() }
                        .tag(2)
                }
                .tabViewStyle(.automatic)

                // Bottom bar
                HStack(alignment: .center) {
                    if currentPage < 2 {
                        Button("Skip") { completeOnboarding() }
                            .buttonStyle(.plain)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .leading)
                    } else {
                        Color.clear.frame(width: 60, height: 1)
                    }

                    Spacer()

                    // Page dots
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { i in
                            Capsule()
                                .fill(i == currentPage ? MokuTheme.coral : Color.secondary.opacity(0.15))
                                .frame(width: i == currentPage ? 24 : 8, height: 8)
                        }
                    }
                    .animation(.spring(duration: 0.4), value: currentPage)

                    Spacer()
                    Color.clear.frame(width: 60, height: 1)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 32)
            }
            .opacity(appeared ? 1 : 0)
        }
        .frame(width: 640, height: 480)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
        }
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
    @Environment(\.colorScheme) private var colorScheme
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Illustrated bookmark
            ZStack {
                // Glow behind the bookmark
                Circle()
                    .fill(MokuTheme.coral.opacity(0.12))
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)

                BookmarkIllustration()
                    .frame(width: 80, height: 100)
            }
            .padding(.bottom, 32)

            Text("Welcome to Moku")
                .font(.system(size: 32, weight: .bold, design: .serif))
                .tracking(-0.5)
                .padding(.bottom, 10)

            Text("Your cozy reading companion")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            Text("Import EPUB, PDF, TXT, CBZ, and HTML books,\ntrack your progress, and read distraction-free on your Mac.")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Spacer()

            Button(action: onNext) {
                Text("Get Started")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: 220)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(MokuTheme.coral)
            .controlSize(.large)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 60)
    }
}

// MARK: - Import Page

private struct ImportPage: View {
    let onNext: () -> Void
    let onImport: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(MokuTheme.violet.opacity(0.1))
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)

                BookStackIllustration()
                    .frame(width: 90, height: 90)
            }
            .padding(.bottom, 32)

            Text("Import Your Books")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .tracking(-0.3)
                .padding(.bottom, 10)

            Text("Add EPUB, PDF, TXT, CBZ, and HTML files from your Mac.\nYour library stays local, fully offline.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Spacer()

            VStack(spacing: 12) {
                Button(action: onImport) {
                    Label("Import books", systemImage: "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: 220)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(MokuTheme.violet)
                .controlSize(.large)

                Button("I'll do this later") { onNext() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 60)
    }
}

// MARK: - Sync Page

private struct SyncPage: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.1))
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)

                SyncIllustration()
                    .frame(width: 80, height: 80)
            }
            .padding(.bottom, 32)

            Text("Sync Across Devices")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .tracking(-0.3)
                .padding(.bottom, 10)

            Text("Moku works fully offline — no account needed.")
                .font(.system(size: 14, weight: .medium))
                .padding(.bottom, 6)

            Text("Want to sync books and progress across devices?\nConnect your own PocketBase server in Settings.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Spacer()

            Button(action: onFinish) {
                Label("Start Reading", systemImage: "book.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: 220)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(MokuTheme.coral)
            .controlSize(.large)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 60)
    }
}

// MARK: - Custom Illustrations

private struct BookmarkIllustration: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // Shadow
            var shadowPath = Path()
            shadowPath.addRoundedRect(
                in: CGRect(x: w * 0.18, y: h * 0.06, width: w * 0.64, height: h * 0.88),
                cornerSize: CGSize(width: 8, height: 8)
            )
            context.fill(shadowPath, with: .color(.black.opacity(0.08)))

            // Bookmark body
            var path = Path()
            let bx = w * 0.15
            let bw = w * 0.7
            let topR: CGFloat = 8

            path.move(to: CGPoint(x: bx + topR, y: 0))
            path.addLine(to: CGPoint(x: bx + bw - topR, y: 0))
            path.addQuadCurve(to: CGPoint(x: bx + bw, y: topR),
                              control: CGPoint(x: bx + bw, y: 0))
            path.addLine(to: CGPoint(x: bx + bw, y: h))
            path.addLine(to: CGPoint(x: bx + bw / 2, y: h * 0.78))
            path.addLine(to: CGPoint(x: bx, y: h))
            path.addLine(to: CGPoint(x: bx, y: topR))
            path.addQuadCurve(to: CGPoint(x: bx + topR, y: 0),
                              control: CGPoint(x: bx, y: 0))
            path.closeSubpath()

            // Gradient fill
            let gradient = Gradient(colors: [
                Color(red: 0.97, green: 0.55, blue: 0.35),
                Color(red: 0.84, green: 0.37, blue: 0.27)
            ])
            context.fill(path, with: .linearGradient(
                gradient, startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: h)
            ))

            // Highlight stripe
            var highlight = Path()
            highlight.addRoundedRect(
                in: CGRect(x: bx + 6, y: 0, width: 4, height: h * 0.72),
                cornerSize: CGSize(width: 2, height: 2)
            )
            context.fill(highlight, with: .color(.white.opacity(0.25)))
        }
    }
}

private struct BookStackIllustration: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            let books: [(x: CGFloat, y: CGFloat, bw: CGFloat, bh: CGFloat, color: Color, rotation: Double)] = [
                (0.12, 0.35, 0.32, 0.60, MokuTheme.violet.opacity(0.8), -6),
                (0.30, 0.20, 0.35, 0.70, MokuTheme.coral.opacity(0.9), 2),
                (0.50, 0.28, 0.30, 0.65, Color.teal.opacity(0.7), 8),
            ]

            for book in books {
                context.drawLayer { ctx in
                    let bx = w * book.x
                    let by = h * book.y
                    let bw = w * book.bw
                    let bh = h * book.bh

                    ctx.translateBy(x: bx + bw / 2, y: by + bh / 2)
                    ctx.rotate(by: Angle(degrees: book.rotation))
                    ctx.translateBy(x: -(bx + bw / 2), y: -(by + bh / 2))

                    // Shadow
                    let shadowRect = CGRect(x: bx + 2, y: by + 3, width: bw, height: bh)
                    var shadow = Path()
                    shadow.addRoundedRect(in: shadowRect, cornerSize: CGSize(width: 4, height: 4))
                    ctx.fill(shadow, with: .color(.black.opacity(0.1)))

                    // Book body
                    let rect = CGRect(x: bx, y: by, width: bw, height: bh)
                    var body = Path()
                    body.addRoundedRect(in: rect, cornerSize: CGSize(width: 4, height: 4))
                    ctx.fill(body, with: .color(book.color))

                    // Spine
                    var spine = Path()
                    spine.addRect(CGRect(x: bx, y: by, width: 4, height: bh))
                    ctx.fill(spine, with: .color(.white.opacity(0.2)))
                }
            }
        }
    }
}

private struct SyncIllustration: View {
    var body: some View {
        ZStack {
            // Two overlapping device outlines
            RoundedRectangle(cornerRadius: 8)
                .stroke(MokuTheme.violet.opacity(0.3), lineWidth: 2)
                .frame(width: 36, height: 50)
                .rotationEffect(.degrees(-10))
                .offset(x: -14, y: 4)

            RoundedRectangle(cornerRadius: 8)
                .stroke(MokuTheme.coral.opacity(0.3), lineWidth: 2)
                .frame(width: 36, height: 50)
                .rotationEffect(.degrees(10))
                .offset(x: 14, y: 4)

            // Sync arrows
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [MokuTheme.violet, MokuTheme.coral],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .offset(y: -8)
        }
    }
}
