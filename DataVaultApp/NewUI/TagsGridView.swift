// Copyright © 2025 Zama. All rights reserved.

import Algorithms
import SwiftUI

#Preview {
    @Previewable @State var selection: Set<String> = []
    let words = ["Swift", "UIKit", "SwiftUI", "Combine", "CoreDataAndFriends", "ARKit", "SceneKit", "Metal", "SwiftPM", "CocoaPods"]
    
    TagsGrid(items: words, chunkedBy: 4, selection: $selection) { word, isSelected in
        Text(word)
            .bold()
            .padding(8)
            .background(isSelected ? .black : .gray.opacity(0.2))
            .foregroundStyle(isSelected ? .white : .black)
    }
    
    Spacer()
    Text("selection: \(selection)")
}

struct TagsGrid<Cell: View>: View {
    let items: [String]
    let chunkedBy: Int
    let selection: Binding<Set<String>>
    let content: (String, Bool) -> Cell
    
    var body: some View {
        VStack {
            ForEach(items.chunks(ofCount: chunkedBy), id: \.self) { line in
                HStack {
                    ForEach(line, id: \.self) { word in
                        Button {
                            if selection.wrappedValue.contains(word) {
                                selection.wrappedValue.remove(word)
                            } else {
                                selection.wrappedValue.insert(word)
                            }
                        } label: {
                            content(word, selection.wrappedValue.contains(word))
                        }
                    }
                }
            }
        }
    }
}
