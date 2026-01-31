#!/usr/bin/perl
# log_filter.pl — tmux pipe-pane 用ログフィルタ
# Claude Code TUIの生出力からANSIエスケープ・TUI再描画ノイズを除去し、
# エージェントの実質的な出力テキストのみを記録する。
#
# 使い方: tmux pipe-pane -t PANE -o "perl /path/to/log_filter.pl >> out.log"

use strict;
use warnings;

$| = 1;  # autoflush

# 直近の出力行を保持（重複ブロック検出用）
my @recent;
my $WINDOW = 20;  # 直近20行以内に同じ行があればスキップ

while (<STDIN>) {
    # 1) ANSIエスケープシーケンス除去
    s/\e\].*?(?:\x07|\e\\)//g;          # OSC
    s/\e\[[0-9;]*[a-zA-Z]//g;           # CSI
    s/\e\[\?[0-9;]*[a-zA-Z]//g;         # CSI private
    s/\e\[>[0-9;]*[a-zA-Z]//g;          # CSI >
    s/\e\[<[a-zA-Z]//g;                 # CSI <
    s/\e[()][0-9A-Z]//g;                # charset
    s/\x0f//g;                           # SI
    s/\r//g;                             # CR

    # 2) 非ASCII除去
    s/[^\x20-\x7E\n\t]//g;

    # 3) 複数スペース圧縮
    s/[ \t]{2,}/ /g;

    # 4) trim
    s/^\s+//;
    s/\s+$//;

    # 5) 空行スキップ
    next if /^$/;

    # === TUI UIノイズ除去 ===

    # Claude Code ウェルカム画面・バナー
    next if /^Claude Code$/;
    next if /^v\d+\.\d+/;
    next if /^Welcome back/;
    next if /^Opus \d/;
    next if /^Claude Max/;
    next if /^~\//;
    next if /^Try "/;

    # パーミッション・ショートカットUI
    next if /bypass/i;
    next if /permissions?\s*on/;
    next if /shift\+Tab/;
    next if /\bcycle\b/;

    # ステータスバー
    next if /\[Opus/;
    next if /uesama\s*\(main/;
    next if /\$\d+\.\d+/;
    next if /^\| \d+s/;
    next if /^\+\d+ -\d+/;
    next if /Visual Studio/;
    next if /\/ide\b/;
    next if /\/mcp\b/;
    next if /^\d+ MCP/;
    next if /^\(auth\)/;
    next if /^\(main\)/;

    # 思考中インジケータ（Claude Codeの各種アニメーション表示）
    next if /^Noodling/;
    next if /^Perusing/;
    next if /^Pondering/;
    next if /^Thinking/;
    next if /^Harmonizing/;
    next if /^Pollinating/;
    next if /^Transfiguring/;
    next if /^Running$/;
    next if /^Waiting$/;
    next if /^Reading \d+ file/;
    next if /^Read \d+ file/;
    next if /^\(ctrl\+o/;
    next if /^expand\)/;
    next if /running stop hook/;

    # ファイルパス断片（ステータスバーのパス折り返し）
    next if /^\.uesama\//;
    next if /^uctions\/kashi/;
    next if /^ructions/;
    next if /^tructions/;
    next if /^tions\//;
    next if /^ions\//;
    next if /^myo\.md/;
    next if /^hin\.md/;
    next if /^nbo\.md/;

    # キューファイルパス断片
    next if /^s\/kashin\d/;
    next if /^ks\/kashin\d/;
    next if /^sks\/kashin\d/;
    next if /^orts\/kashin\d/;
    next if /^queue\/reports/;
    next if /^\/queue\/reports/;
    next if /^ueue\/reports/;
    next if /^in\d+_report/;
    next if /^hin\d+_report/;
    next if /^n\d+_report/;
    next if /^_report\.yaml/;

    # 短い行除去（空白除去後10文字以下）
    my $stripped = $_;
    $stripped =~ s/\s//g;
    next if length($stripped) <= 10;

    # 直近N行以内に同じ行があればスキップ（TUI再描画の繰り返し対策）
    my $is_dup = 0;
    for my $r (@recent) {
        if ($r eq $_) {
            $is_dup = 1;
            last;
        }
    }
    next if $is_dup;

    push @recent, $_;
    shift @recent if @recent > $WINDOW;

    print "$_\n";
}
