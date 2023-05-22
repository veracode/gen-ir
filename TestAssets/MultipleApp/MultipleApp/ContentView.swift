//
//  ContentView.swift
//  MultipleApp
//
//  Created by Thomas Hedderwick on 19/05/2023.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
					#if COPY_ONLY
						Text(CopyOnly.get())
					#else
            Text("Hello, world!")
					#endif
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
