import 'dart:io';
import 'dart:math';

import 'package:animated_digit/animated_digit.dart';
import 'package:cdk_flutter/cdk_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sats_app/bloc/user.dart';
import 'package:sats_app/bloc/wallet.dart';
import 'package:sats_app/screen/activity.dart';
import 'package:sats_app/screen/components.dart';
import 'package:sats_app/screen/onboarding.dart';
import 'package:sats_app/screen/recovery.dart';
import 'package:sats_app/screen/settings.dart';
import 'package:sats_app/screen/transact.dart';

class HomeScreen extends StatefulWidget {
  static Route route({bool hideTransition = false}) {
    if (hideTransition) {
      return PageRouteBuilder(pageBuilder: (context, _, _) => const HomeScreen(), transitionDuration: Duration.zero);
    }

    if (Platform.isIOS) {
      return CupertinoPageRoute(builder: (context) => HomeScreen());
    }

    return MaterialPageRoute(builder: (context) => HomeScreen());
  }

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _showOnboarding = false;

  Widget get _page {
    switch (_currentIndex) {
      case 0:
        return TransactScreen();
      case 1:
        return ActivityScreen();
      default:
        return const Center(child: Text('Unknown page'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletCubit, WalletState>(
      builder: (context, state) {
        final walletCubit = context.read<WalletCubit>();
        final wallet = state.wallet;

        if (state.isLoading) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (state.hasSeed == false) {
          return RecoveryScreen();
        }

        if (_showOnboarding || state.currentMint == null || wallet == null) {
          return OnboardingScreen(
            onJoinMint: (mintUrl) async {
              await walletCubit.switchMint(mintUrl);
              setState(() {
                _currentIndex = 0;
                _showOnboarding = false;
              });
            },
            onCancel: () {
              setState(() {
                _showOnboarding = false;
              });
            },
          );
        }

        return WalletProvider(
          wallet: wallet,
          child: Scaffold(
            body: _page,
            appBar: AppBar(
              leading: _MenuButton(),
              title: _AppBarTitle(wallet: wallet),
              actions: [
                BlocBuilder<UserCubit, UserState>(
                  builder: (context, userState) {
                    return Stack(
                      children: [
                        IconButton(
                          icon: Icon(Icons.settings),
                          onPressed: () {
                            Navigator.push(context, SettingsScreen.route());
                          },
                        ),
                        if (!userState.isSeedBackedUp)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
            drawer: _Drawer(
              onMintSelected: (mintUrl) async {
                await walletCubit.switchMint(mintUrl);
                setState(() {
                  _currentIndex = 0;
                });
              },
              onShowOnboarding: () {
                setState(() {
                  _showOnboarding = true;
                });
              },
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              items: [
                BottomNavigationBarItem(
                  icon: Transform.rotate(angle: -pi / 4, child: Icon(Icons.swap_horiz)),
                  label: 'Transact',
                ),
                BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Activity'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.menu),
      onPressed: () {
        Scaffold.of(context).openDrawer();
      },
    );
  }
}

class _Drawer extends StatelessWidget {
  final void Function(String) onMintSelected;
  final VoidCallback onShowOnboarding;

  const _Drawer({required this.onMintSelected, required this.onShowOnboarding});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletCubit, WalletState>(
      builder: (context, state) {
        final mints = state.mints;
        final listViewWidgets = <Widget>[];
        if (mints == null || mints.isEmpty) {
          listViewWidgets.add(
            ListTile(
              title: Text('No Wallets Found'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          );
        } else {
          for (final mint in mints) {
            listViewWidgets.add(
              ListTile(
                title: Text(mint.info?.name ?? mint.url),
                subtitle: (mint.balance != null) ? Text(formatAmount(mint.balance!)) : null,
                trailing: (mint.url == state.currentMintUrl || mint.balance == null || mint.balance! > BigInt.zero)
                    ? null
                    : IconButton(
                        onPressed: (state.currentMintUrl != mint.url)
                            ? () async {
                                await context.read<WalletCubit>().removeMint(mint.url);
                              }
                            : null,
                        icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.error),
                      ),
                onTap: (state.currentMintUrl != mint.url)
                    ? () async {
                        onMintSelected(mint.url);
                      }
                    : null,
              ),
            );
          }
        }

        return Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
                child: Column(
                  children: [
                    Text(
                      state.currentMint?.info?.name ?? 'Wallets',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(color: Theme.of(context).colorScheme.onPrimary),
                    ),
                    SizedBox(height: 8),
                    Text(
                      state.currentMint?.url ?? 'No active wallet',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onPrimary),
                    ),
                  ],
                ),
              ),
              ...listViewWidgets,
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: OutlinedButton.icon(
                  icon: Icon(Icons.add),
                  label: Text('Join another mint'),
                  onPressed: () {
                    Navigator.pop(context);
                    onShowOnboarding();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextButton.icon(
                  icon: Icon(Icons.admin_panel_settings),
                  label: Text('Manage a mint'),
                  onPressed: () {
                    // TODO: Implement mint management navigation
                  },
                ),
              ),
              SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

class _AppBarTitle extends StatelessWidget {
  final Wallet wallet;

  const _AppBarTitle({required this.wallet});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        WalletBalanceBuilder(
          builder: (context, balance) {
            if (!balance.hasData) {
              return CircularProgressIndicator();
            }
            return AnimatedDigitWidget(
              value: balance.data?.toInt(),
              suffix: ' sat',
              enableSeparator: true,
              textStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            );
          },
        ),
        IconButton(
          icon: Icon(Icons.add_circle_outlined),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              enableDrag: false,
              builder: (context) => _DepositSheet(wallet: wallet),
            );
          },
        ),
      ],
    );
  }
}

class _DepositSheet extends StatefulWidget {
  final Wallet wallet;
  const _DepositSheet({required this.wallet});

  @override
  _DepositSheetState createState() => _DepositSheetState();
}

class _DepositSheetState extends State<_DepositSheet> {
  BigInt? _amount;
  bool _isSheetExpanded = false;
  bool _isIssued = false;
  String? _error;

  Widget _build(BuildContext context) {
    if (_amount == null) {
      return _DepositSheetAmountInput(
        onAmountSubmitted: (amount) {
          setState(() {
            _amount = amount;
            _isSheetExpanded = true;
          });
        },
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Theme.of(context).colorScheme.error, size: 48),
            SizedBox(height: 16),
            Text(_error!, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      );
    }

    if (_isIssued) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.tertiary, size: 48),
            SizedBox(height: 16),
            Text('Received $_amount sat.', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      );
    }

    return _DepositSheetMintQuote(
      amount: _amount!,
      onComplete: (error) {
        setState(() {
          _isSheetExpanded = false;
          _isIssued = error == null;
          _error = error;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WalletProvider(
      wallet: widget.wallet,
      child: Padding(
        padding: EdgeInsetsGeometry.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: MediaQuery.of(context).size.height * (_isSheetExpanded ? 0.75 : 0.3),
          decoration: BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: _build(context),
        ),
      ),
    );
  }
}

class _DepositSheetAmountInput extends StatefulWidget {
  final Function(BigInt?) onAmountSubmitted;

  const _DepositSheetAmountInput({required this.onAmountSubmitted});

  @override
  State<_DepositSheetAmountInput> createState() => _DepositSheetAmountInputState();
}

class _DepositSheetAmountInputState extends State<_DepositSheetAmountInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Request focus after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Enter Deposit Amount', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            decoration: InputDecoration(labelText: 'Amount', suffixText: 'sat', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, _ThousandsSeparatorInputFormatter()],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: CupertinoButton.filled(
              onPressed: () {
                widget.onAmountSubmitted(BigInt.tryParse(_controller.text.replaceAll(',', '')));
              },
              child: Text('Generate Deposit Request'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DepositSheetMintQuote extends StatelessWidget {
  final BigInt amount;
  final Function(String? error) onComplete;

  const _DepositSheetMintQuote({required this.amount, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return MintQuoteBuilder(
      amount: amount,
      listener: (quote) async {
        if (quote.state == MintQuoteState.issued || quote.state == MintQuoteState.error) {
          await Future.delayed(Duration(milliseconds: 300));
          onComplete(quote.error);
        }
      },
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Theme.of(context).colorScheme.error, size: 48),
                SizedBox(height: 16),
                Text(snapshot.error.toString(), style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
          );
        }
        final quote = snapshot.data;
        if (quote == null) {
          return Center(child: Text('No quote available'));
        }

        final isPaid = quote.state == MintQuoteState.paid || quote.state == MintQuoteState.issued;
        final screenWidth = MediaQuery.of(context).size.width;
        final qrSize = screenWidth * 0.6;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon in circle container
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primary),
                child: Icon(Icons.add_circle, color: Colors.white, size: 32),
              ),
              Spacer(),
              // Headline text
              Text(
                'Deposit ${amount.toString()} sat',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              Spacer(flex: 2),
              // QR code
              QrImageView(data: quote.request, size: qrSize),
              // Status row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPaid ? Icons.check_circle : Icons.pending,
                    color: isPaid ? Theme.of(context).colorScheme.tertiary : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isPaid ? 'Deposit Paid' : 'Deposit Pending',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isPaid ? Theme.of(context).colorScheme.tertiary : Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              Spacer(flex: 2),
              // Read-only selectable text field with monospace font
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  quote.request,
                  style:
                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontFeatures: [FontFeature.tabularFigures()],
                      ) ??
                      const TextStyle(fontFamily: 'monospace'),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  enableInteractiveSelection: true,
                ),
              ),
              Spacer(),
              // Copy button at the bottom
              Align(
                alignment: Alignment.bottomCenter,
                child: TextButton.icon(
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy Request'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: quote.request));
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    try {
      final number = int.parse(newText);
      final formatter = NumberFormat.decimalPattern('en_US');
      String formatted = formatter.format(number);
      int cursorOffset = formatted.length - newText.length;

      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: newValue.selection.baseOffset + cursorOffset),
      );
    } catch (e) {
      return oldValue;
    }
  }
}
