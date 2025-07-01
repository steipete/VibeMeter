import SwiftUI

/// Terminal-style UI components inspired by ccseva
struct TerminalStyleView: View {
    @StateObject private var viewModel = TerminalStyleViewModel(provider: .claude)
    @State private var commandInput = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal output
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(viewModel.outputLines) { line in
                            TerminalLine(line: line)
                                .id(line.id)
                        }
                    }
                    .padding()
                }
                .background(Color.black)
                .onChange(of: viewModel.outputLines.count) {
                    withAnimation {
                        proxy.scrollTo(viewModel.outputLines.last?.id, anchor: .bottom)
                    }
                }
            }
            
            // Command input
            HStack(spacing: 8) {
                Text("$")
                    .foregroundColor(.green)
                    .font(.custom("SF Mono", size: 14))
                
                TextField("Type command...", text: $commandInput)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.custom("SF Mono", size: 14))
                    .foregroundColor(.white)
                    .focused($isInputFocused)
                    .onSubmit {
                        viewModel.currentCommand = commandInput
                        viewModel.executeCommand()
                        commandInput = ""
                    }
            }
            .padding()
            .background(Color.black.opacity(0.9))
        }
        .frame(minWidth: 600, minHeight: 400)
        .background(Color.black)
        .onAppear {
            isInputFocused = true
        }
    }
}

/// Individual terminal line
struct TerminalLine: View {
    let line: TerminalStyleViewModel.OutputLine
    
    var body: some View {
        HStack(spacing: 0) {
            if let prefix = line.prefix {
                Text(prefix)
                    .foregroundColor(line.prefixColor)
                    .font(.custom("SF Mono", size: 13))
            }
            
            Text(line.content)
                .foregroundColor(line.color)
                .font(.custom("SF Mono", size: 13))
            
            Spacer()
        }
    }
}

/// Standalone terminal status widget
struct TerminalStatusWidget: View {
    let provider: ServiceProvider
    @StateObject private var viewModel: TerminalMonitor
    
    init(provider: ServiceProvider) {
        self.provider = provider
        self._viewModel = StateObject(wrappedValue: TerminalMonitor(provider: provider))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack {
                Text("[\(provider.displayName)]")
                    .foregroundColor(.cyan)
                
                Spacer()
                
                if viewModel.isActive {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.green.opacity(0.5), lineWidth: 4)
                                .scaleEffect(true ? 1.5 : 1.0)
                                .opacity(true ? 0 : 1)
                                .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: true)
                        )
                }
            }
            
            // Status lines
            ForEach(viewModel.statusLines, id: \.self) { line in
                Text(line)
                    .font(.custom("SF Mono", size: 11))
                    .foregroundColor(.gray)
            }
            
            // Progress bar
            if let progress = viewModel.progress > 0 ? viewModel.progress : nil {
                TerminalProgressBar(progress: progress, width: 200)
            }
        }
        .padding()
        .background(Color.black.opacity(0.9))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            viewModel.startMonitoring()
        }
    }
}

/// Terminal-style progress bar
struct TerminalProgressBar: View {
    let progress: Double
    let width: CGFloat
    
    var body: some View {
        HStack(spacing: 2) {
            Text("[")
                .foregroundColor(.gray)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Text(String(repeating: "━", count: 20))
                        .foregroundColor(.gray.opacity(0.3))
                    
                    // Progress
                    Text(String(repeating: "━", count: Int(progress * 20)))
                        .foregroundColor(progressColor)
                }
            }
            .frame(width: width - 60)
            
            Text("]")
                .foregroundColor(.gray)
            
            Text("\(Int(progress * 100))%")
                .foregroundColor(progressColor)
                .frame(width: 40, alignment: .trailing)
        }
        .font(.custom("SF Mono", size: 11))
    }
    
    private var progressColor: Color {
        if progress > 0.9 { return .red }
        if progress > 0.7 { return .orange }
        return .green
    }
}

/// ASCII-style gauge component
struct ASCIIGauge: View {
    let value: Double // 0-1
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            // Gauge
            HStack(spacing: 1) {
                ForEach(0..<10) { i in
                    Rectangle()
                        .fill(i < Int(value * 10) ? barColor : Color.gray.opacity(0.3))
                        .frame(width: 15, height: 30)
                }
            }
            
            // Scale
            HStack {
                Text("0")
                Spacer()
                Text("50")
                Spacer()
                Text("100")
            }
            .font(.custom("SF Mono", size: 9))
            .foregroundColor(.gray)
            
            // Label and value
            Text("\(label): \(Int(value * 100))%")
                .font(.custom("SF Mono", size: 11))
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(4)
    }
    
    private var barColor: Color {
        if value > 0.9 { return .red }
        if value > 0.7 { return .orange }
        if value > 0.5 { return .yellow }
        return .green
    }
}

/// Matrix-style animated background
struct MatrixBackground: View {
    @State private var offset = CGSize.zero
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<20) { column in
                    MatrixColumn(height: geometry.size.height)
                        .position(
                            x: CGFloat(column) * 30 + 15,
                            y: geometry.size.height / 2
                        )
                }
            }
        }
        .background(Color.black)
    }
}

struct MatrixColumn: View {
    let height: CGFloat
    @State private var offset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<30) { _ in
                Text(randomCharacter())
                    .font(.custom("SF Mono", size: 12))
                    .foregroundColor(.green.opacity(Double.random(in: 0.1...0.8)))
            }
        }
        .offset(y: offset)
        .onAppear {
            withAnimation(.linear(duration: Double.random(in: 5...15)).repeatForever(autoreverses: false)) {
                offset = height
            }
        }
    }
    
    private func randomCharacter() -> String {
        let characters = "ｦｱｳｴｵｶｷｹｺｻｼｽｾｿﾀﾂﾃﾅﾆﾇﾈﾊﾋﾎﾏﾐﾑﾒﾓﾔﾕﾗﾘﾜﾝ0123456789"
        return String(characters.randomElement() ?? "ｱ")
    }
}

/// Terminal command palette
struct TerminalCommandPalette: View {
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    let onCommand: (TerminalCommand) -> Void
    
    private let commands = TerminalCommand.allCommands
    
    private var filteredCommands: [TerminalCommand] {
        if searchText.isEmpty {
            return commands
        }
        return commands.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search commands...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.custom("SF Mono", size: 14))
                    .foregroundColor(.white)
                    .focused($isSearchFocused)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            .background(Color.black.opacity(0.9))
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Commands list
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredCommands) { command in
                        CommandRow(command: command) {
                            onCommand(command)
                            isPresented = false
                        }
                    }
                }
            }
            .background(Color.black.opacity(0.8))
        }
        .frame(width: 500, height: 400)
        .background(Color.black.opacity(0.95))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.green.opacity(0.5), lineWidth: 1)
        )
        .onAppear {
            isSearchFocused = true
        }
    }
}

struct CommandRow: View {
    let command: TerminalCommand
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(command.name)
                            .font(.custom("SF Mono", size: 13))
                            .foregroundColor(.green)
                        
                        if let shortcut = command.shortcut {
                            Text(shortcut)
                                .font(.custom("SF Mono", size: 11))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(command.description)
                        .font(.custom("SF Mono", size: 11))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if isHovered {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(isHovered ? Color.green.opacity(0.1) : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct TerminalCommand: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let shortcut: String?
    let action: String
    
    static let allCommands = [
        TerminalCommand(name: "status", description: "Show current usage status", shortcut: "⌘S", action: "status"),
        TerminalCommand(name: "burn", description: "Display burn rate analysis", shortcut: "⌘B", action: "burn"),
        TerminalCommand(name: "predict", description: "Show usage predictions", shortcut: "⌘P", action: "predict"),
        TerminalCommand(name: "sessions", description: "List Claude sessions", shortcut: nil, action: "sessions"),
        TerminalCommand(name: "gaps", description: "Analyze session gaps", shortcut: nil, action: "gaps"),
        TerminalCommand(name: "velocity", description: "Show velocity trends", shortcut: "⌘V", action: "velocity"),
        TerminalCommand(name: "alerts", description: "View active alerts", shortcut: "⌘A", action: "alerts"),
        TerminalCommand(name: "clear", description: "Clear terminal output", shortcut: "⌘K", action: "clear"),
        TerminalCommand(name: "help", description: "Show available commands", shortcut: "⌘?", action: "help")
    ]
}