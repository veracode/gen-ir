//
//  ContentView.swift
//  ManyTargetTest
//
//  Created by Thomas Hedderwick on 17/04/2023.
//

import SwiftUI
import ManyFramework

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text(ManyFrameworkString)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
