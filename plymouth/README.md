# Екран завантаження Pavver

Тема Plymouth, яка показує анімацію екрана входу під час завантаження, вимкнення та перезавантаження системи.
Кожна подія має власний підпис.

## Системні вимоги

- Plymouth із модулем `script`.
- Параметр ядра `splash`.
- Initramfs, зібраний із Plymouth.

## Встановлення

```bash
sudo ./install.sh --system --component plymouth --activate
```

Команда встановлює тему, вибирає її в Plymouth і вмикає `pavver-quiet-shutdown.service`.
Без `--activate` файли лише встановлюються.
Після активації перезберіть initramfs і додайте `splash` до параметрів ядра, бо ці кроки залежать від системи.

Пакет дистрибутива не змінює налаштування, тому після нього виконайте:

```bash
sudo plymouth-set-default-theme pavver
sudo systemctl enable pavver-quiet-shutdown.service
```

## Повідомлення під час вимкнення

Перед появою Plymouth на консолі виводиться широкомовне повідомлення про вимкнення.
`pavver-quiet-shutdown.service` вимикає такі повідомлення в `systemd-logind`, тому попередження не отримують і сесії SSH.

## Оновлення кадрів

Plymouth не виконує QML, тому `frames/` містить заздалегідь відрендерений цикл `LoginLoader`, а `labels/` містить підписи.
Обидва каталоги оновлює одна команда, якій потрібен робочий графічний сеанс:

```bash
./scripts/render-plymouth-frames.sh
```

## Перевірка на ZFS

`boot-environment-test.sh` призначений для системи автора з ZFSBootMenu та dracut і містить її назви датасетів.
Команда `create` збирає окреме завантажувальне середовище для перевірки, `apply` переносить Plymouth на основну систему, а `remove` видаляє тестове середовище.
