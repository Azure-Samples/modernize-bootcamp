using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace eShopLite.StoreFx.Models
{
    // Table name pinned: EF Core would otherwise derive it from the DbSet name ("Users").
    [Table("User")]
    public class User
    {
        public int Id { get; set; }

        [Required]
        [StringLength(50)]
        public string UserName { get; set; }

        [Required]
        [StringLength(100)]
        public string Email { get; set; }

        // Legacy: salted SHA1. Kept deliberately weak so the modernization lab has something to fix.
        [Required]
        [StringLength(40)]
        public string PasswordHash { get; set; }

        [Required]
        [StringLength(24)]
        public string PasswordSalt { get; set; }

        // Legacy: roles as a comma-separated string instead of a proper join table.
        [StringLength(200)]
        public string Roles { get; set; }

        public bool IsApproved { get; set; }

        public DateTime CreatedUtc { get; set; }

        public DateTime? LastLoginUtc { get; set; }
    }
}
