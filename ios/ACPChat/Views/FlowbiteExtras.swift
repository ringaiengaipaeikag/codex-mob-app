//
//  FlowbiteExtras.swift
//
//  Дополнительные REGHelp-styled примитивы, портированные из Flowbite
//  (`themesberg/flowbite` · /content). Все используют токены из
//  DesignSystem.swift — те же Indigo/Cyan/Pink и motion-константы.
//
//  Покрыто:
//    - RSpinner               (components/spinner.md)
//    - RProgressBar           (components/progress.md)
//    - RSkeleton / RSkeletonBlock (components/skeleton.md)
//    - RToast / ToastCenter   (components/toast.md)
//    - RTabs / RTabItem       (components/tabs.md)
//    - RListGroup             (components/list-group.md)
//    - RTimeline              (components/timeline.md) — идеально под DG-протокол
//    - RAccordion             (components/accordion.md)
//    - RStepper               (components/stepper.md)
//    - RPopover               (components/popover.md · tooltip-style bubble)
//    - RDrawer                (components/drawer.md)
//    - RBottomNav             (components/bottom-navigation.md)
//

import SwiftUI
import Combine

// MARK: - Spinner

/// `components/spinner.md` — indigo circular spinner, 4 sizes.
struct RSpinner: View {
    enum Size { case sm, md, lg, xl
        var side: CGFloat { switch self { case .sm: return 16; case .md: return 24; case .lg: return 32; case .xl: return 48 } }
        var line: CGFloat { switch self { case .sm: return 2; case .md: return 2.5; case .lg: return 3; case .xl: return 4 } }
    }
    var size: Size = .md
    var tint: Color = DS.primary
    @State private var rotate = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(
                LinearGradient(colors: [tint.opacity(0.15), tint],
                               startPoint: .top, endPoint: .bottom),
                style: StrokeStyle(lineWidth: size.line, lineCap: .round)
            )
            .frame(width: size.side, height: size.side)
            .rotationEffect(.degrees(rotate ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: rotate)
            .onAppear { rotate = true }
    }
}

// MARK: - Progress bar

/// `components/progress.md`.
struct RProgressBar: View {
    let value: Double          // 0...1
    var color: ChipColor = .indigo
    var height: CGFloat = 8
    var showLabel: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showLabel {
                HStack {
                    Text("\(Int(value * 100))%")
                        .font(DS.tXs)
                        .foregroundStyle(DS.inkDim)
                    Spacer()
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                        .fill(color.bg)
                    RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                        .fill(color.fg)
                        .frame(width: max(0, min(1, value)) * geo.size.width)
                        .animation(DS.easeOut, value: value)
                }
            }
            .frame(height: height)
        }
    }
}

// MARK: - Skeleton

/// `components/skeleton.md` — shimmering placeholder.
struct RSkeleton: View {
    var height: CGFloat = 12
    var width: CGFloat? = nil
    var radius: CGFloat = 6
    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(DS.P.g200)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.0),
                                .white.opacity(0.5),
                                .white.opacity(0.0),
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .mask(Rectangle())
                    .offset(x: phase * 200)
            )
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

struct RSkeletonSessionRow: View {
    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(Color.clear).frame(width: 4)
            VStack(alignment: .leading, spacing: 8) {
                RSkeleton(height: 14, width: 140)
                HStack(spacing: 8) {
                    RSkeleton(height: 10, width: 60)
                    RSkeleton(height: 10, width: 80)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            Spacer()
        }
        .background(
            RoundedRectangle(cornerRadius: DS.rXl, style: .continuous).fill(DS.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.rXl, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        )
    }
}

// MARK: - Toast

/// `components/toast.md` — slide-from-bottom notification card.
struct RToast: Identifiable, Equatable {
    let id: UUID = UUID()
    let kind: Kind
    let title: String
    let body: String?
    var duration: Double = 3.5
    enum Kind { case info, success, warning, danger
        var color: ChipColor {
            switch self { case .info: return .indigo; case .success: return .green
                         case .warning: return .yellow; case .danger: return .red }
        }
        var icon: String {
            switch self { case .info: return "info.circle.fill"
                         case .success: return "checkmark.circle.fill"
                         case .warning: return "exclamationmark.triangle.fill"
                         case .danger: return "xmark.octagon.fill" }
        }
    }
}

@MainActor
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()
    @Published private(set) var queue: [RToast] = []

    func push(_ t: RToast) {
        queue.append(t)
        Task {
            try? await Task.sleep(nanoseconds: UInt64(t.duration * 1_000_000_000))
            await MainActor.run {
                queue.removeAll { $0.id == t.id }
            }
        }
    }
    func dismiss(_ id: UUID) { queue.removeAll { $0.id == id } }
}

struct RToastHost: View {
    @ObservedObject var center = ToastCenter.shared

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            ForEach(center.queue) { t in
                toastCard(t)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .padding(.horizontal, DS.s4)
        .padding(.bottom, DS.s4)
        .animation(DS.easeOut, value: center.queue.map(\.id))
        .allowsHitTesting(!center.queue.isEmpty)
    }

    private func toastCard(_ t: RToast) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: t.kind.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(t.kind.color.fg)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.title).font(DS.tLabel).foregroundStyle(DS.ink)
                if let body = t.body {
                    Text(body).font(DS.tXs).foregroundStyle(DS.inkDim)
                }
            }
            Spacer(minLength: 0)
            Button { ToastCenter.shared.dismiss(t.id) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.inkFaint)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.rXl, style: .continuous).fill(DS.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.rXl, style: .continuous)
                .stroke(DS.hairlineMid, lineWidth: 1)
        )
        .shadowDropdown()
    }
}

// MARK: - Tabs

/// `components/tabs.md` — underline style, indigo active bar.
struct RTabs<Selection: Hashable>: View {
    @Binding var selection: Selection
    let items: [(value: Selection, label: String, icon: String?)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.value) { item in
                Button { withAnimation(DS.easeOutFast) { selection = item.value } } label: {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            if let icon = item.icon {
                                Image(systemName: icon).font(.system(size: 13, weight: .medium))
                            }
                            Text(item.label).font(DS.tLabel)
                        }
                        .foregroundStyle(selection == item.value ? DS.primary : DS.inkMuted)
                        Rectangle()
                            .fill(selection == item.value ? DS.primary : Color.clear)
                            .frame(height: 2)
                    }
                    .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(DS.hairlineMid).frame(height: 1)
        }
    }
}

// MARK: - List group

/// `components/list-group.md` — linked rows with optional chevron.
struct RListGroup<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(
                RoundedRectangle(cornerRadius: DS.rXl, style: .continuous).fill(DS.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.rXl, style: .continuous)
                    .stroke(DS.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.rXl, style: .continuous))
    }
}

struct RListRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var tint: Color = DS.primary
    var trailing: AnyView? = nil
    var chevron: Bool = true
    var isLast: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button { action?() } label: {
            HStack(spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.12))
                        )
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(DS.tLabel).foregroundStyle(DS.ink)
                    if let subtitle {
                        Text(subtitle).font(DS.tXs).foregroundStyle(DS.inkMuted)
                    }
                }
                Spacer()
                if let trailing { trailing }
                if chevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.inkFaint)
                }
            }
            .padding(14)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(DS.hairline)
                    .frame(height: 1)
                    .padding(.leading, 54)
            }
        }
    }
}

// MARK: - Timeline (идеально под DG multi-agent протокол)

/// `components/timeline.md`. Каждое событие — точка + линия вниз.
/// Для DG: точка = агент с его тинтом, заголовок = `[TURN → ...]`, body = реплика.
struct RTimeline<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
    }
}

struct RTimelineItem: View {
    let title: String
    var subtitle: String? = nil
    var tint: Color = DS.primary
    var icon: String? = nil
    var isLast: Bool = false
    @ViewBuilder var body_: () -> AnyView

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(tint).frame(width: 14, height: 14)
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
                if !isLast {
                    Rectangle()
                        .fill(DS.hairlineMid)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 14)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(title).font(DS.tLabel).foregroundStyle(DS.ink)
                    if let subtitle {
                        Text(subtitle).font(DS.tXs).foregroundStyle(DS.inkMuted)
                    }
                    Spacer()
                }
                body_()
            }
            .padding(.bottom, isLast ? 0 : 18)
        }
    }
}

// MARK: - Accordion

struct RAccordion<Content: View>: View {
    let title: String
    var icon: String? = nil
    @State private var open = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Button { withAnimation(DS.easeOutFast) { open.toggle() } } label: {
                HStack(spacing: 10) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DS.primary)
                    }
                    Text(title).font(DS.tLabel).foregroundStyle(DS.ink)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.inkMuted)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .padding(14)
            }
            .buttonStyle(.plain)
            if open {
                Divider().background(DS.hairline)
                content.padding(14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DS.rXl, style: .continuous).fill(DS.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.rXl, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.rXl, style: .continuous))
    }
}

// MARK: - Stepper

struct RStepper: View {
    let steps: [String]
    @Binding var current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(i <= current ? DS.primary : DS.P.g200)
                            .frame(width: 22, height: 22)
                        if i < current {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.white)
                        } else {
                            Text("\(i + 1)")
                                .font(DS.body(11, weight: .semibold))
                                .foregroundStyle(i <= current ? .white : DS.inkMuted)
                        }
                    }
                    Text(step)
                        .font(DS.tXs)
                        .foregroundStyle(i <= current ? DS.ink : DS.inkMuted)
                }
                if i < steps.count - 1 {
                    Rectangle()
                        .fill(i < current ? DS.primary : DS.P.g200)
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Popover (tooltip-style)

struct RPopover<Trigger: View, Body: View>: View {
    @State private var shown = false
    @ViewBuilder var trigger: Trigger
    @ViewBuilder var body_: Body

    var body: some View {
        trigger
            .onTapGesture { withAnimation(DS.easeOutFast) { shown.toggle() } }
            .popover(isPresented: $shown, arrowEdge: .top) {
                body_
                    .padding(12)
                    .background(DS.surface)
                    .presentationCompactAdaptation(.popover)
            }
    }
}

// MARK: - Drawer (side-sliding panel)

struct RDrawer<Content: View>: View {
    @Binding var isOpen: Bool
    var width: CGFloat = 320
    var edge: Edge = .trailing
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: edge == .trailing ? .trailing : .leading) {
            if isOpen {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(DS.easeOut) { isOpen = false } }
                    .transition(.opacity)
                panel
                    .transition(.move(edge: edge))
            }
        }
        .animation(DS.easeOut, value: isOpen)
    }

    private var panel: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { withAnimation(DS.easeOut) { isOpen = false } } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.inkDim)
                        .padding(10)
                }
                .buttonStyle(.plain)
            }
            content
            Spacer()
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .background(DS.surface.ignoresSafeArea())
        .shadowModal()
    }
}

// MARK: - Bottom navigation (mobile tab bar alt)

struct RBottomNav<Selection: Hashable>: View {
    @Binding var selection: Selection
    let items: [(value: Selection, label: String, icon: String)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.value) { item in
                Button { selection = item.value } label: {
                    VStack(spacing: 2) {
                        Image(systemName: item.icon)
                            .font(.system(size: 18, weight: .semibold))
                        Text(item.label).font(DS.body(10, weight: .medium))
                    }
                    .foregroundStyle(selection == item.value ? DS.primary : DS.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .background(DS.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(DS.hairline).frame(height: 1)
        }
    }
}
