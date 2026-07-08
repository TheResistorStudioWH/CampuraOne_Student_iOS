//
//  StudentLoginConfirmView.swift
//  CampuraOne
//

import SwiftUI

struct StudentLoginConfirmView: View {
    let user: AppUser
    let student: Student?
    var onContinue: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "person.text.rectangle.fill")
                    .font(.title2)
                    .foregroundStyle(.accent)
                Text("请确认信息")
                    .font(.title2.bold())
            }

            VStack(alignment: .leading, spacing: 12) {
                infoRow(title: "账号", value: user.userName)
                infoRow(title: "用户 ID", value: "\(user.userID)")
                if let studentID = user.studentID {
                    infoRow(title: "学生 ID", value: "\(studentID)")
                }
                if let student {
                    infoRow(title: "姓名", value: student.studentName)
                    infoRow(title: "学校 ID", value: "\(student.schoolID)")
                    infoRow(title: "院系 / 班级", value: "\(student.departmentID) / \(student.classID)")
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )

            Text("账号由校方统一下发，无渠道擅自注册。若信息有误，请联系校方处理。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                onContinue?()
            } label: {
                Text("我已确认无误，继续进入 Campura One")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
        }
        .padding(20)
    }

    @ViewBuilder
    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
