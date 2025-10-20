import SwiftUI

struct ExpandableFAB: View {
    @Binding var isExpanded: Bool
    let onScanISBN: () -> Void
    let onAddBook: () -> Void

    private let animation = Animation.spring(response: 0.3, dampingFraction: 0.7)

    var body: some View {
        VStack(alignment: .trailing, spacing: 16) {
            if isExpanded {
                FABOption(
                    icon: "barcode.viewfinder",
                    label: "Scan ISBN",
                    color: .green,
                    action: performScan
                )
                .transition(optionTransition)

                FABOption(
                    icon: "plus",
                    label: "Add Book",
                    color: .orange,
                    action: performAdd
                )
                .transition(optionTransition)
            }

            Button {
                withAnimation(animation) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "xmark" : "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .rotationEffect(.degrees(isExpanded ? 45 : 0))
                    .shadow(radius: 6, x: 0, y: 4)
            }
            .accessibilityLabel(isExpanded ? "Close actions" : "More actions")
        }
        .padding()
    }

    private var optionTransition: AnyTransition {
        .scale.combined(with: .opacity)
    }

    private func performScan() {
        withAnimation(animation) {
            isExpanded = false
        }
        onScanISBN()
    }

    private func performAdd() {
        withAnimation(animation) {
            isExpanded = false
        }
        onAddBook()
    }
}

private struct FABOption: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                Image(systemName: icon)
                    .font(.headline)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(color)
            .clipShape(Capsule())
            .shadow(radius: 4, x: 0, y: 3)
        }
        .accessibilityLabel(label)
    }
}

#if DEBUG
struct ExpandableFAB_Previews: PreviewProvider {
    static var previews: some View {
        ExpandableFAB(
            isExpanded: .constant(true),
            onScanISBN: {},
            onAddBook: {}
        )
        .preferredColorScheme(.light)
        .previewLayout(.sizeThatFits)
    }
}
#endif
