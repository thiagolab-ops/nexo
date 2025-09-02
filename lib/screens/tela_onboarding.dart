import 'package:flutter/material.dart';

class OnboardingInfo {
  final IconData icon;
  final String title;
  final String description;

  OnboardingInfo({required this.icon, required this.title, required this.description});
}

class TelaOnboarding extends StatefulWidget {
  final VoidCallback onFinish;

  const TelaOnboarding({super.key, required this.onFinish});

  @override
  State<TelaOnboarding> createState() => _TelaOnboardingState();
}

class _TelaOnboardingState extends State<TelaOnboarding> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingInfo> _pages = [
    OnboardingInfo(
      icon: Icons.style,
      title: 'Bem-vindo ao Nexo!',
      description: 'Sua nova plataforma de estudos centralizada. Comece criando Baralhos e Flashcards para memorizar qualquer assunto.',
    ),
    OnboardingInfo(
      icon: Icons.group_work,
      title: 'Estude em Comunidade',
      description: 'Crie ou participe de Hubs de estudo para colaborar, compartilhar materiais e conversar com outros estudantes.',
    ),
    OnboardingInfo(
      icon: Icons.dynamic_feed,
      title: 'Conecte-se e Aprenda',
      description: 'Siga professores e colegas no Feed Social para descobrir novos conteúdos e baralhos gerados pela comunidade.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.85),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemBuilder: (context, index) {
                final page = _pages[index];
                return Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(page.icon, size: 120, color: Colors.lightBlueAccent),
                      const SizedBox(height: 32),
                      Text(
                        page.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        page.description,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[400]),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: widget.onFinish,
            child: const Text('PULAR', style: TextStyle(color: Colors.white70)),
          ),
          Row(
            children: List.generate(
              _pages.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _currentPage == index ? 24 : 8,
                decoration: BoxDecoration(
                  color: _currentPage == index ? Colors.lightBlueAccent : Colors.grey,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (_currentPage == _pages.length - 1) {
                widget.onFinish();
              } else {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              }
            },
            child: Text(_currentPage == _pages.length - 1 ? 'CONCLUIR' : 'PRÓXIMO'),
          ),
        ],
      ),
    );
  }
}
