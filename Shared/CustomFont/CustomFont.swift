// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    ForEach(Font.TextStyle.allCases, id: \.self) { font in
        HStack(alignment: .firstTextBaseline) {
            let name = String(describing: font).capitalized
            Text(name).customFont(font)
            Text(name).font(.system(font))
        }
    }
    Spacer()
}

extension View {
    func customFont(_ style: Font.TextStyle) -> some View {
        self.modifier(CustomFontModifier(style: style))
            .lineSpacing(4)
    }
}

struct CustomFontModifier: ViewModifier {
    let style: Font.TextStyle
    
    private let regular = "Telegraf-Regular"
    private let bold = "Telegraf-Bold"
    private let ultraBold = "Telegraf-UltraBold"
    
    func body(content: Content) -> some View {
        //        return content.font(.system(style))
        switch style {
        case .largeTitle: content.font(.custom(ultraBold, size: 30))
        case .title: content.font(.custom(bold, size: 28))
        case .title2: content.font(.custom(bold, size: 22))
        case .title3: content.font(.custom(bold, size: 20))
        case .headline: content.font(.custom(bold, size: 17))
        case .subheadline: content.font(.custom(regular, size: 15))
        case .body: content.font(.custom(regular, size: 17))
        case .callout: content.font(.custom(regular, size: 16))
        case .footnote: content.font(.custom(regular, size: 13))
        case .caption: content.font(.custom(regular, size: 12))
        case .caption2: content.font(.custom(regular, size: 11))
        default: content.font(.custom(regular, size: 11))
        }
    }
}
