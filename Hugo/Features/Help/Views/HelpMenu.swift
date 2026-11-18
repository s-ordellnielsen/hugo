import SwiftUI

/// A question mark in the toolbar that lists the help articles for the
/// current screen and opens the chosen one in a sheet. It stays a menu even
/// with one article, so help looks and works the same on every screen.
struct HelpMenu: View {
    let articles: [HelpArticle]

    @State private var presentedArticle: HelpArticle?

    var body: some View {
        Menu {
            ForEach(articles) { article in
                Button {
                    presentedArticle = article
                } label: {
                    Label {
                        Text(article.title)
                    } icon: {
                        Image(systemName: article.systemImage)
                    }
                }
            }
        } label: {
            Label {
                Text("help.menu.label")
            } icon: {
                Image(systemName: "questionmark.circle")
            }
        }
        .sheet(item: $presentedArticle) { article in
            HelpView(for: article.resourceName)
        }
    }
}

#Preview {
    NavigationStack {
        Text(verbatim: "Screen")
            .toolbar {
                ToolbarItem {
                    HelpMenu(articles: HelpArticle.year)
                }
            }
    }
}
