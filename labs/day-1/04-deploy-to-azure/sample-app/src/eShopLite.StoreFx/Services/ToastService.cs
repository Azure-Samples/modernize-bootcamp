using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace eShopLite.StoreFx.Services
{
    public enum ToastKind
    {
        Success,
        Info,
        Warning,
        Error
    }

    public sealed class Toast
    {
        public Guid Id { get; } = Guid.NewGuid();
        public string Message { get; set; }
        public ToastKind Kind { get; set; }
    }

    /// <summary>
    /// Replaces the TempData messages the MVC controllers set before redirecting. Scoped to the
    /// circuit, so a toast raised by one component reaches the host rendered by the layout.
    /// </summary>
    public sealed class ToastService
    {
        private static readonly TimeSpan Lifetime = TimeSpan.FromSeconds(4);

        private readonly List<Toast> _toasts = new List<Toast>();

        public event Action Changed;

        public IReadOnlyList<Toast> Toasts
        {
            get { return _toasts.ToList(); }
        }

        public void Show(string message, ToastKind kind = ToastKind.Success)
        {
            if (string.IsNullOrWhiteSpace(message))
            {
                return;
            }

            var toast = new Toast { Message = message, Kind = kind };
            _toasts.Add(toast);
            Changed?.Invoke();

            _ = ExpireAsync(toast.Id);
        }

        public void Dismiss(Guid id)
        {
            if (_toasts.RemoveAll(t => t.Id == id) > 0)
            {
                Changed?.Invoke();
            }
        }

        private async Task ExpireAsync(Guid id)
        {
            await Task.Delay(Lifetime);
            Dismiss(id);
        }
    }
}
