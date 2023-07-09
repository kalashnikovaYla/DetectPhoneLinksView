//
//  ContentView.swift
//  DetectPhoneLinksView
//
//  Created by sss on 09.07.2023.
//

import SwiftUI

struct ContentView: View {
    let text = "Hello! Go to https://github.com/kalashnikovaYla +7(982)709-77-77"
    
    var body: some View {
        VStack(alignment:.leading) {
            Spacer()
            LinkedText(text)
         
            Text("My phone [8(988)710-11-12](89887101112)")
            Text("Url [https://github.com](https://github.com)")
            Spacer()
            
        }
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct LinkColoredText: View {
    enum Component {
        case text(String)
        case link(String, URL)
        case phoneNumber(String)
    }

    let text: String
    let components: [Component]

    init(text: String, links: [NSTextCheckingResult], phoneNumbers: [NSTextCheckingResult]) {
        self.text = text
        let nsText = text as NSString

        var components: [Component] = []
        var index = 0
        var linkIndex = 0
        var phoneNumberIndex = 0


        let sortedResults = (links + phoneNumbers).sorted { $0.range.lowerBound < $1.range.lowerBound }

        for result in sortedResults {
            if result.range.location > index {
                components.append(.text(nsText.substring(with: NSRange(location: index, length: result.range.location - index))))
            }
            
            if result.resultType == .link {
                components.append(.link(nsText.substring(with: result.range), result.url!))
                index = result.range.location + result.range.length
                linkIndex += 1
            } else if result.resultType == .phoneNumber {
                components.append(.phoneNumber(nsText.substring(with: result.range)))
                index = result.range.location + result.range.length
                phoneNumberIndex += 1
            }
        }

        if index < nsText.length {
            components.append(.text(nsText.substring(from: index)))
        }

        self.components = components
    }

    var body: some View {
        components.map { component in
            switch component {
            case .text(let text):
                return Text(verbatim: text)
            case .link(let text, _):
                return Text(verbatim: text)
                    .foregroundColor(.blue)
                    .underline()
            case .phoneNumber(let text):
                return Text(verbatim: text)
                    .foregroundColor(.blue)
                    .underline()
            }
        }.reduce(Text(""), +)
    }
}
 

struct LinkedText: View {
    let text: String
    let links: [NSTextCheckingResult]
    let phoneNumbers: [NSTextCheckingResult]
    
    init (_ text: String) {
        self.text = text
        let nsText = text as NSString

        let linkDetector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let phoneNumberDetector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue)
        let wholeString = NSRange(location: 0, length: nsText.length)
        links = linkDetector.matches(in: text, options: [], range: wholeString)
        phoneNumbers = phoneNumberDetector.matches(in: text, options: [], range: wholeString)
    }
    
    var body: some View {
        LinkColoredText(text: text, links: links, phoneNumbers: phoneNumbers)
            .font(.body)
            .overlay(LinkTapOverlay(text: text, links: links, phoneNumbers: phoneNumbers))
    }
}

private struct LinkTapOverlay: UIViewRepresentable {
    let text: String
    let links: [NSTextCheckingResult]
    let phoneNumbers: [NSTextCheckingResult]
    
    func makeUIView(context: Context) -> LinkTapOverlayView {
        let view = LinkTapOverlayView()
        view.textContainer = context.coordinator.textContainer
        
        view.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didTapLabel(_:)))
        tapGesture.delegate = context.coordinator
        view.addGestureRecognizer(tapGesture)
        
        return view
    }
    
    func updateUIView(_ uiView: LinkTapOverlayView, context: Context) {
        let attributedString = NSAttributedString(string: text, attributes: [.font: UIFont.preferredFont(forTextStyle: .body)])
        context.coordinator.textStorage = NSTextStorage(attributedString: attributedString)
        context.coordinator.textStorage!.addLayoutManager(context.coordinator.layoutManager)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let overlay: LinkTapOverlay

        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: .zero)
        var textStorage: NSTextStorage?
        
        init(_ overlay: LinkTapOverlay) {
            self.overlay = overlay
            
            textContainer.lineFragmentPadding = 0
            textContainer.lineBreakMode = .byWordWrapping
            textContainer.maximumNumberOfLines = 0
            layoutManager.addTextContainer(textContainer)
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            let location = touch.location(in: gestureRecognizer.view!)
            let result = link(at: location) ?? phoneNumber(at: location)
            return result != nil
        }
        
        @objc func didTapLabel(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: gesture.view!)
            guard let result = link(at: location) ?? phoneNumber(at: location) else {
                return
            }

            if let url = result.url {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else if let phoneNumber = result.phoneNumber {
                let phoneUrl = URL(string: "tel://\(phoneNumber)")
                UIApplication.shared.open(phoneUrl!, options: [:], completionHandler: nil)
            }
        }
        
        private func link(at point: CGPoint) -> NSTextCheckingResult? {
            guard !overlay.links.isEmpty else {
                return nil
            }

            let indexOfCharacter = layoutManager.characterIndex(
                for: point,
                in: textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )

            return overlay.links.first { $0.range.contains(indexOfCharacter) }
        }
        
        private func phoneNumber(at point: CGPoint) -> NSTextCheckingResult? {
            guard !overlay.phoneNumbers.isEmpty else {
                return nil
            }

            let indexOfCharacter = layoutManager.characterIndex(
                for: point,
                in: textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )

            return overlay.phoneNumbers.first { $0.range.contains(indexOfCharacter) }
        }
    }
}



private class LinkTapOverlayView: UIView {
    var textContainer: NSTextContainer!
    
    override func layoutSubviews() {
        super.layoutSubviews()

        var newSize = bounds.size
        newSize.height += 20
        textContainer.size = newSize
    }
}
