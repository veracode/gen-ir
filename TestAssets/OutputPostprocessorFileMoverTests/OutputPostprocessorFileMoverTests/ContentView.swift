//
//  ContentView.swift
//  OutputPostprocessorFileMoverTests
//
//  Created by Thomas Hedderwick on 22/09/2023.
//

import SwiftUI
import ImageFramework
import ImageLibrary

struct ContentView: View {
	var body: some View {
		VStack {
			SwiftUI.Image(systemName: "globe")
				.imageScale(.large)
				.foregroundStyle(.tint)
			Text("Hello, world!")
			ImageFramework.Image()
			Image()
			ImageLibrary.Image()
		}
		.padding()
	}
}

#Preview {
	ContentView()
}
