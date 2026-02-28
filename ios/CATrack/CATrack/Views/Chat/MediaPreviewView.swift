import SwiftUI

struct MediaPreviewView: View {
    let attachment: MediaAttachment

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 64, height: 64)

            if let thumbData = attachment.thumbnailData,
               let uiImage = UIImage(data: thumbData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var iconName: String {
        switch attachment.type {
        case .image: return "photo"
        case .video: return "video"
        case .audio: return "waveform"
        case .file: return "doc"
        }
    }
}
