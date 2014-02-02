


ssize_t fop_slotcar_write(struct file *filp, const char *buff, size_t len, loff_t *offp);
ssize_t fop_slotcar_read(struct file *filp, char __user *buff, size_t count, loff_t *offp);
int fop_slotcar_open(struct inode *inode, struct file *filp);

extern const struct file_operations fops_slotcar;


