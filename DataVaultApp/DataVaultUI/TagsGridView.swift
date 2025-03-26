// Copyright © 2025 Zama. All rights reserved.

import Algorithms
import SwiftUI

#Preview {
    @Previewable @State var selection: Set<DogBreed> = []
    let dogs = DogBreed.allCases
    
    TagsGrid(items: dogs, chunkedBy: 4, selection: $selection) { item, isSelected in
        Text(item.rawValue)
            .bold()
            .padding(8)
            .background(isSelected ? .black : .gray.opacity(0.2))
            .foregroundStyle(isSelected ? .white : .black)
    }
    
    Spacer()
    Text("selection: \(selection)")
}

struct TagsGrid<Cell: View, Item: Hashable>: View {
    let items: [Item]
    let chunkedBy: Int
    let selection: Binding<Set<Item>>
    let content: (Item, Bool) -> Cell
    
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

enum DogBreed: String, CaseIterable {
    case goldenRetriever = "Golden Retriever"
    case germanShepherd = "German Shepherd"
    case labrador = "Labrador"
    case bulldog = "Bulldog"
    case poodle = "Poodle"
    case beagle = "Beagle"
    case rottweiler = "Rottweiler"
    case dachshund = "Dachshund"
    case boxer = "Boxer"
    case husky = "Husky"
}
