//
//  OverviewListStyle.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 04/09/2026.
//

import SwiftUI

enum OverviewListStyle: String, CaseIterable {
	case byDate
	case byEntry
	
	var iconName: String {
		switch self {
			case .byDate: "calendar"
			case .byEntry: "list.bullet"
		}
	}
	
	var accessibilityLabel: LocalizedStringKey {
		switch self {
			case .byDate: "a11y.overview.list-style.by-date"
			case .byEntry: "a11y.overview.list-style.by-entry"
		}
	}
}
