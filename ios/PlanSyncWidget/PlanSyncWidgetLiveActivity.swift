// PlanSync — Live Activity widget.
//
// Add this file to the "PlanSyncWidget" Widget Extension target (see
// ios/PlanSyncWidget/README_SETUP.md). It renders the app's *next plan* on the
// Lock Screen and in the Dynamic Island, styled like an in-app plan card.
//
// Data is shared from Flutter via the `live_activities` package, which writes
// each value into the App Group UserDefaults under "<activityId>_<key>".

import ActivityKit
import WidgetKit
import SwiftUI

// Must match the App Group added to BOTH the Runner and PlanSyncWidget targets.
let sharedDefault = UserDefaults(suiteName: "group.com.supremolabs.plansync")!

struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public typealias LiveDeliveryData = ContentState
  public struct ContentState: Codable, Hashable {}
  var id = UUID()
}

extension LiveActivitiesAppAttributes {
  func prefixedKey(_ key: String) -> String { "\(id)_\(key)" }
}

// PlanSync palette.
private let bg = Color(hex: "0A0E14")
private let accent = Color(hex: "2DD4BF")
private let textSecondary = Color.white.opacity(0.55)

extension Color {
  init(hex: String) {
    let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    var v: UInt64 = 0
    Scanner(string: h).scanHexInt64(&v)
    self = Color(
      .sRGB,
      red: Double((v >> 16) & 0xFF) / 255,
      green: Double((v >> 8) & 0xFF) / 255,
      blue: Double(v & 0xFF) / 255,
      opacity: 1
    )
  }
}

private func val(_ ctx: ActivityViewContext<LiveActivitiesAppAttributes>, _ key: String) -> String {
  sharedDefault.string(forKey: ctx.attributes.prefixedKey(key)) ?? ""
}

struct PlanSyncWidgetLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
      // Lock Screen / banner.
      let color = Color(hex: val(context, "colorHex"))
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text(val(context, "category").uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(color)
          Spacer()
          Text(val(context, "tripName"))
            .font(.system(size: 11))
            .foregroundColor(textSecondary)
            .lineLimit(1)
        }
        Text(val(context, "title"))
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(.white)
          .lineLimit(1)
        HStack(spacing: 10) {
          Label(val(context, "timeRange"), systemImage: "clock")
            .font(.system(size: 13))
            .foregroundColor(.white)
          if !val(context, "location").isEmpty {
            Label(val(context, "location"), systemImage: "mappin.and.ellipse")
              .font(.system(size: 13))
              .foregroundColor(textSecondary)
              .lineLimit(1)
          }
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(bg)
      .activityBackgroundTint(bg)
      .activitySystemActionForegroundColor(accent)
    } dynamicIsland: { context in
      let color = Color(hex: val(context, "colorHex"))
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "location.fill").foregroundColor(color)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(val(context, "timeRange")).font(.system(size: 13)).foregroundColor(.white)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 2) {
            Text(val(context, "title")).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
            if !val(context, "location").isEmpty {
              Text(val(context, "location")).font(.system(size: 12)).foregroundColor(textSecondary)
            }
          }.frame(maxWidth: .infinity, alignment: .leading)
        }
      } compactLeading: {
        Image(systemName: "airplane").foregroundColor(accent)
      } compactTrailing: {
        Text(val(context, "timeRange")).font(.system(size: 12)).foregroundColor(.white)
      } minimal: {
        Image(systemName: "location.fill").foregroundColor(accent)
      }
    }
  }
}
