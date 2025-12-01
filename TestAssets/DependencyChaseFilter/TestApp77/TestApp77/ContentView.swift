//
//  ContentView.swift
//  TestApp77
//
//  Created by Keith Johnson on 9/19/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
        .onAppear {
            // printVersionInfo prints TestLibraryA's info.  TestLibraryA in turn prints TestLibraryB's info
            VersionPrinter.printVersionInfo()
            
            // Now print TestLibraryC's info
            VersionPrinterC.printVersionInfoC()
        }
    }
}

#Preview {
    ContentView()
}
