//
//  ContentView.swift
//  SPMTest
//
//  Created by Thomas Hedderwick on 24/05/2024.
//

import SwiftUI
import MyLibrary

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
          Text("VERSION: \(MyLibrary.version)")
          Text("view: \(MyLibrary.view)")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
