//
//  ContentView.swift
//  App
//
//  Created by Thomas Hedderwick on 24/08/2023.
//

import SwiftUI
import Framework

struct ContentView: View {
	let framework: Framework = .init(model: .init(name: "ContentView"))

	var body: some View {
		VStack {
			framework.icon
				.imageScale(.large)
				.foregroundStyle(.tint)
			Text("Hello, \(framework.model.name)!")
		}
		.padding()
	}
}

#Preview {
	ContentView()
}
