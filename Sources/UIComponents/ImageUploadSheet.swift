import SwiftUI

public struct ImageUploadSheet: View {
    private let root: AppRootViewModel

    public init(root: AppRootViewModel) {
        self.root = root
    }

    public var body: some View {
        @Bindable var root = root

        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("view.imageUploadWindow"))
                .font(.title2)
                .bold()

#if os(macOS)
            Text(L10n.text("imageUpload.hint"))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button(L10n.text("imageUpload.insert")) {
                    root.insertImage()
                }

                Button(L10n.text("common.cancel")) {
                    root.isImageUploadPresented = false
                }
            }
#else
            Text(L10n.text("imageUpload.unavailable"))
                .foregroundStyle(.secondary)

            Button(L10n.text("common.ok")) {
                root.isImageUploadPresented = false
            }
#endif

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 220)
    }
}
