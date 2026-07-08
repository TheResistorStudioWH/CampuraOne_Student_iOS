//
//  QRLoginPlaceholderView.swift
//  CampuraOne
//

import SwiftUI

struct QRLoginPlaceholderView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 52))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)

            Text("扫码登录")
                .font(.title3.bold())

            Text("学校注册账号时会同步下发二维码。后续可通过扫描学生证 / 学生卡上的专属二维码直接登录。")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Text("该功能将在后续版本开放")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}
