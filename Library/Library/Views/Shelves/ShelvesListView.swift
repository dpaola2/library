import SwiftUI

struct ShelvesListView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "books.vertical")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                    .padding(.top, 32)

                Text("Your shelves will appear here once the data layer hooks in.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("My Shelves")
        }
    }
}

#Preview {
    ShelvesListView()
}
