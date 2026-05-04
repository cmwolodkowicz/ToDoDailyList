import SwiftUI

struct SplashView: View {
    @State private var opacity = 0.0

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 72))
                .foregroundStyle(Color("Accent"))
            Text("DailyList")
                .font(.largeTitle.weight(.bold))
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.4)) { opacity = 1 }
        }
    }
}
