
import SwiftUI

struct AdView: View {
    @State var ad: AdModel
    
    var body: some View {
        HStack(alignment: .top) {
            texts
            Spacer()
            image
                .scaledToFit()
                .frame(width: 100, height: 100)
            
        }
        .padding()
        .background {
            image
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(.thinMaterial)
        }
    }
    
    private var texts: some View {
        VStack(alignment: .leading) {
            Text(ad.title)
                .customFont(.headline)
                .foregroundStyle(.primary)
            
            Text(ad.details)
                .customFont(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    @ViewBuilder
    private var image: some View {
        if let uiImage = UIImage(named: "AdImages/" + ad.imageName) {
            Image(uiImage: uiImage)
                .resizable()
        } else {
            Image(systemName: "photo.badge.exclamationmark")
                .resizable()
                .fontWeight(.thin)
                .opacity(0.3)
                .overlay {
                    Text("Unzip AdImages.zip to view image")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.red)
                }
        }
    }
}
