//
//  MyHomeWidgetBundle.swift
//  MyHomeWidget
//
//  Created by Furkan Efe Aktan on 2026-01-28.
//

import WidgetKit
import SwiftUI

@main
struct MyHomeWidgetBundle: WidgetBundle {
    var body: some Widget {
        MyHomeWidget()
        MyHomeWidgetControl()
        MyHomeWidgetLiveActivity()
    }
}
