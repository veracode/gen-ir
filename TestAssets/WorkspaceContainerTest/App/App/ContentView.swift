//
//  ContentView.swift
//  App
//
//  Created by Thomas Hedderwick on 04/09/2023.
//

import SwiftUI
import FrameworkA
import FrameworkB

struct ContentView: View {
	var body: some View {
		VStack {
			Image(systemName: "globe")
				.imageScale(.large)
				.foregroundColor(.accentColor)
			Text("Hello, world!")
			Text(FrameworkA.name)
			Text(FrameworkB.name)
		}
		.padding()
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}
